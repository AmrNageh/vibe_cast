import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'walkie_talkie_event_state.dart';
import '../services/audio_capture_service.dart';
import '../services/audio_playback_service.dart';
import '../services/udp_transport_service.dart';
import '../services/walkie_signal_service.dart';
import '../services/walkie_repository.dart';
import '../models/online_user_entity.dart';

@lazySingleton
class WalkieTalkieBloc extends Bloc<WalkieTalkieEvent, WalkieTalkieState> {
  final AudioCaptureService _audioCaptureService;
  final AudioPlaybackService _audioPlaybackService;
  final UdpTransportService _udpTransportService;
  final WalkieSignalService _walkieSignalService;
  final WalkieRepository _walkieRepository;

  StreamSubscription? _audioCaptureSub;
  StreamSubscription? _udpAudioSub;
  StreamSubscription? _pttSignalSub;

  WalkieTalkieBloc(
    this._audioCaptureService,
    this._audioPlaybackService,
    this._udpTransportService,
    this._walkieSignalService,
    this._walkieRepository,
  ) : super(WalkieTalkieInitial()) {
    on<WalkieInitialized>(_onInitialized);
    on<WalkieChannelEntered>(_onChannelEntered);
    on<WalkieOnlineUsersUpdated>(_onOnlineUsersUpdated);
    on<WalkiePTTPressed>(_onPTTPressed);
    on<WalkiePTTReleased>(_onPTTReleased);
    on<WalkieIncomingTransmission>(_onIncomingTransmission);
    on<WalkieTransmissionEnded>(_onTransmissionEnded);
    on<WalkieHistoryUpdated>(_onHistoryUpdated);
    on<WalkieChatHistoryUpdated>(_onChatHistoryUpdated);
    on<WalkieChatMessageReceived>(_onChatMessageReceived);
    on<WalkieGroupCreated>(_onGroupCreated);
    on<WalkieGroupJoinedByInvite>(_onGroupJoinedByInvite);
    on<WalkieCodecToggled>(_onCodecToggled);
  }

  Future<void> _onInitialized(WalkieInitialized event, Emitter<WalkieTalkieState> emit) async {
    emit(WalkieTalkieLoading());
    try {
      await _udpTransportService.initialize();
      // Connect to the signaling server
      _walkieSignalService.connect('https://vibe2-hxn784go.b4a.run');
      
      _pttSignalSub = _walkieSignalService.pttStream.listen((data) {
        if (data['type'] == 'start') {
          add(WalkieIncomingTransmission(
            senderId: data['senderId'] ?? '',
            senderName: data['senderName'] ?? 'Unknown',
            udpIp: data['udpIp'] ?? '127.0.0.1',
            udpPort: data['udpPort'] ?? 41234,
          ));
        } else if (data['type'] == 'stop') {
          add(WalkieTransmissionEnded(data['senderId'] ?? ''));
        }
      });
      _walkieSignalService.onlineUsersStream.listen((data) {
        final onlineUsers = data.map((u) => OnlineUserEntity.fromJson(u)).toList();
        add(WalkieOnlineUsersUpdated(onlineUsers));
      });
      _walkieSignalService.historyStream.listen((data) {
        add(WalkieHistoryUpdated(data));
      });
      _walkieSignalService.chatHistoryStream.listen((data) {
        add(WalkieChatHistoryUpdated(data));
      });
      _walkieSignalService.chatStream.listen((data) {
        add(WalkieChatMessageReceived(data));
      });
      _walkieSignalService.errorStream.listen((errorMsg) {
        // Just emit failure if error happens (like group full)
        emit(WalkieTalkieFailure(errorMsg));
      });

      await _walkieRepository.initIdentity();
      final groups = await _walkieRepository.getGroups();
      emit(WalkieTalkieGroupsLoaded(groups: groups, onlineUsers: const []));
    } catch (e) {
      emit(WalkieTalkieFailure(e.toString()));
    }
  }

  Future<void> _onChannelEntered(WalkieChannelEntered event, Emitter<WalkieTalkieState> emit) async {
    String localIp = '127.0.0.1';
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
      if (interfaces.isNotEmpty && interfaces.first.addresses.isNotEmpty) {
        localIp = interfaces.first.addresses.first.address;
      }
    } catch (_) {}

    _walkieSignalService.joinGroup(event.group.id, _udpTransportService.localPort ?? 0, localIp, _walkieRepository.userName, _walkieRepository.userId);
    emit(WalkieTalkieInChannel(group: event.group));
  }

  Future<void> _onPTTPressed(WalkiePTTPressed event, Emitter<WalkieTalkieState> emit) async {
    final currentState = state;
    if (currentState is WalkieTalkieInChannel && currentState.status == TransmissionStatus.idle) {
      emit(currentState.copyWith(status: TransmissionStatus.transmitting, activeTransmitterName: 'Me'));
      
      await _audioCaptureService.start();
      _audioCaptureSub = _audioCaptureService.audioStream.listen((data) {
        _walkieSignalService.sendAudio(currentState.group.id, _walkieRepository.userId, data);
      });

      _walkieSignalService.startPtt(currentState.group.id, _walkieRepository.userName, _walkieRepository.userId);
    }
  }

  Future<void> _onPTTReleased(WalkiePTTReleased event, Emitter<WalkieTalkieState> emit) async {
    final currentState = state;
    if (currentState is WalkieTalkieInChannel && currentState.status == TransmissionStatus.transmitting) {
      emit(currentState.copyWith(status: TransmissionStatus.idle, activeTransmitterName: null));
      
      await _audioCaptureService.stop();
      await _audioCaptureSub?.cancel();
      _walkieSignalService.stopPtt(currentState.group.id, _walkieRepository.userName, _walkieRepository.userId);
    }
  }

  void _onIncomingTransmission(WalkieIncomingTransmission event, Emitter<WalkieTalkieState> emit) {
    final currentState = state;
    if (currentState is WalkieTalkieInChannel && currentState.status == TransmissionStatus.idle) {
      emit(currentState.copyWith(
        status: TransmissionStatus.receiving,
        activeTransmitterName: event.senderName,
      ));

      _audioPlaybackService.playStream(_walkieSignalService.audioStream);
    }
  }

  void _onTransmissionEnded(WalkieTransmissionEnded event, Emitter<WalkieTalkieState> emit) {
    final currentState = state;
    if (currentState is WalkieTalkieInChannel && currentState.status == TransmissionStatus.receiving) {
      emit(currentState.copyWith(status: TransmissionStatus.idle, activeTransmitterName: null));
      _audioPlaybackService.stop();
    }
  }

  void _onOnlineUsersUpdated(WalkieOnlineUsersUpdated event, Emitter<WalkieTalkieState> emit) {
    final currentState = state;
    if (currentState is WalkieTalkieGroupsLoaded) {
      emit(WalkieTalkieGroupsLoaded(
        groups: currentState.groups,
        onlineUsers: event.onlineUsers,
      ));
    } else if (currentState is WalkieTalkieInChannel) {
      emit(currentState.copyWith(members: event.onlineUsers));
    }
  }

  void _onHistoryUpdated(WalkieHistoryUpdated event, Emitter<WalkieTalkieState> emit) {
    final currentState = state;
    if (currentState is WalkieTalkieInChannel) {
      emit(currentState.copyWith(history: event.history));
    }
  }

  void _onChatHistoryUpdated(WalkieChatHistoryUpdated event, Emitter<WalkieTalkieState> emit) {
    final currentState = state;
    if (currentState is WalkieTalkieInChannel) {
      emit(currentState.copyWith(chatHistory: event.chatHistory));
    }
  }

  void _onChatMessageReceived(WalkieChatMessageReceived event, Emitter<WalkieTalkieState> emit) {
    final currentState = state;
    if (currentState is WalkieTalkieInChannel) {
      final updatedHistory = List<dynamic>.from(currentState.chatHistory)..add(event.message);
      emit(currentState.copyWith(chatHistory: updatedHistory));
    }
  }

  Future<void> _onGroupCreated(WalkieGroupCreated event, Emitter<WalkieTalkieState> emit) async {
    final currentState = state;
    if (currentState is WalkieTalkieGroupsLoaded) {
      try {
        final newGroup = await _walkieRepository.createGroup(event.name, 'Private Group');
        emit(WalkieTalkieGroupsLoaded(
          groups: [...currentState.groups, newGroup],
          onlineUsers: currentState.onlineUsers,
        ));
      } catch (e) {
        emit(WalkieTalkieFailure(e.toString()));
      }
    }
  }

  Future<void> _onGroupJoinedByInvite(WalkieGroupJoinedByInvite event, Emitter<WalkieTalkieState> emit) async {
    final currentState = state;
    if (currentState is WalkieTalkieGroupsLoaded) {
      try {
        final newGroup = await _walkieRepository.joinGroupFromInvite(event.inviteId);
        // Avoid duplicate adding
        if (!currentState.groups.any((g) => g.id == newGroup.id)) {
          emit(WalkieTalkieGroupsLoaded(
            groups: [...currentState.groups, newGroup],
            onlineUsers: currentState.onlineUsers,
          ));
        }
      } catch (e) {
        emit(WalkieTalkieFailure(e.toString()));
      }
    }
  }

  void _onCodecToggled(WalkieCodecToggled event, Emitter<WalkieTalkieState> emit) {
    _audioCaptureService.useOpus = event.useOpus;
    final currentState = state;
    if (currentState is WalkieTalkieGroupsLoaded) {
      emit(WalkieTalkieGroupsLoaded(
        groups: currentState.groups,
        onlineUsers: currentState.onlineUsers,
        useOpus: event.useOpus,
      ));
    }
  }

  @override
  Future<void> close() {
    _audioCaptureSub?.cancel();
    _udpAudioSub?.cancel();
    _pttSignalSub?.cancel();
    return super.close();
  }
}
