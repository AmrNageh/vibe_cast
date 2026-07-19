import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import '../../../core/config/app_config.dart';
import 'walkie_talkie_event_state.dart';
import '../services/audio_capture_service.dart';
import '../services/audio_playback_service.dart';
import '../services/walkie_signal_service.dart';
import '../services/walkie_repository.dart';
import '../models/online_user_entity.dart';
import '../models/chat_message_entity.dart';

@lazySingleton
class WalkieTalkieBloc extends Bloc<WalkieTalkieEvent, WalkieTalkieState> {
  final AudioCaptureService _audioCaptureService;
  final AudioPlaybackService _audioPlaybackService;
  final WalkieSignalService _walkieSignalService;
  final WalkieRepository _walkieRepository;
  StreamSubscription? _audioCaptureSub;
  StreamSubscription? _pttSignalSub;
  StreamSubscription? _onlineUsersSub;
  StreamSubscription? _historySub;
  StreamSubscription? _chatHistorySub;
  StreamSubscription? _chatSub;
  StreamSubscription? _errorSub;

  WalkieTalkieBloc(
    this._audioCaptureService,
    this._audioPlaybackService,
    this._walkieSignalService,
    this._walkieRepository,
  ) : super(WalkieTalkieInitial()) {
    on<WalkieInitialized>(_onInitialized);
    on<WalkieGroupJoined>( (e, emit) {} ); // Not used yet
    on<WalkieGroupLeft>(_onGroupLeft);
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
      // Connect to the signaling server
      _walkieSignalService.connect(AppConfig.serverUrl);
      
      _pttSignalSub?.cancel();
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

      _onlineUsersSub?.cancel();
      _onlineUsersSub = _walkieSignalService.onlineUsersStream.listen((data) {
        final onlineUsers = data.map((u) => OnlineUserEntity.fromJson(u)).toList();
        add(WalkieOnlineUsersUpdated(onlineUsers));
      });

      _historySub?.cancel();
      _historySub = _walkieSignalService.historyStream.listen((data) {
        add(WalkieHistoryUpdated(data));
      });

      _chatHistorySub?.cancel();
      _chatHistorySub = _walkieSignalService.chatHistoryStream.listen((data) {
        final messages = data.map((m) => ChatMessageEntity.fromJson(m)).toList();
        add(WalkieChatHistoryUpdated(messages));
      });

      _chatSub?.cancel();
      _chatSub = _walkieSignalService.chatStream.listen((data) {
        add(WalkieChatMessageReceived(ChatMessageEntity.fromJson(data)));
      });

      _errorSub?.cancel();
      _errorSub = _walkieSignalService.errorStream.listen((errorMsg) {
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

    _walkieSignalService.joinGroup(event.group.id, 0, localIp, _walkieRepository.userName, _walkieRepository.userId);
    emit(WalkieTalkieInChannel(group: event.group));
  }

  Future<void> _onGroupLeft(WalkieGroupLeft event, Emitter<WalkieTalkieState> emit) async {
    _walkieSignalService.leaveGroup(event.groupId);
    try {
      final groups = await _walkieRepository.getGroups();
      emit(WalkieTalkieGroupsLoaded(groups: groups, onlineUsers: const []));
    } catch (_) {
      // Just emit empty if it fails
      emit(const WalkieTalkieGroupsLoaded(groups: [], onlineUsers: []));
    }
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
      emit(currentState.copyWith(status: TransmissionStatus.idle, clearTransmitter: true));
      
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
      emit(currentState.copyWith(status: TransmissionStatus.idle, clearTransmitter: true));
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
      final updatedHistory = List<ChatMessageEntity>.from(currentState.chatHistory)..add(event.message);
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
    _pttSignalSub?.cancel();
    _onlineUsersSub?.cancel();
    _historySub?.cancel();
    _chatHistorySub?.cancel();
    _chatSub?.cancel();
    _errorSub?.cancel();
    return super.close();
  }
}
