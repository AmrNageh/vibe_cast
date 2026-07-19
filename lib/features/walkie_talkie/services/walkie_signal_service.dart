import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

@lazySingleton
class WalkieSignalService {
  io.Socket? _socket;
  
  final _pttController = StreamController<Map<String, dynamic>>.broadcast();
  final _onlineUsersController = StreamController<List<dynamic>>.broadcast();
  final _historyController = StreamController<List<dynamic>>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _chatController = StreamController<Map<String, dynamic>>.broadcast();
  final _chatHistoryController = StreamController<List<dynamic>>.broadcast();
  final _audioController = StreamController<Uint8List>.broadcast();

  Stream<Map<String, dynamic>> get pttStream => _pttController.stream;
  Stream<List<dynamic>> get onlineUsersStream => _onlineUsersController.stream;
  Stream<List<dynamic>> get historyStream => _historyController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<Map<String, dynamic>> get chatStream => _chatController.stream;
  Stream<List<dynamic>> get chatHistoryStream => _chatHistoryController.stream;
  Stream<Uint8List> get audioStream => _audioController.stream;

  void connect(String serverUrl) {
    _socket = io.io(serverUrl, io.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .build());

    _socket?.onConnect((_) {
      debugPrint('WalkieSignalService connected');
    });

    _socket?.on('walkie:ptt_start', (data) => _pttController.add({'type': 'start', ...data}));
    _socket?.on('walkie:ptt_stop', (data) => _pttController.add({'type': 'stop', ...data}));
    _socket?.on('walkie:online_users', (data) => _onlineUsersController.add(data));
    _socket?.on('walkie:history', (data) => _historyController.add(data));
    _socket?.on('walkie:chat_message', (data) => _chatController.add(data));
    _socket?.on('walkie:chat_history', (data) => _chatHistoryController.add(data));
    _socket?.on('walkie:audio', (data) {
      if (data != null && data['audioBlob'] != null) {
        final audioBlob = data['audioBlob'];
        if (audioBlob is Uint8List) {
          _audioController.add(audioBlob);
        } else if (audioBlob is List<dynamic>) {
          _audioController.add(Uint8List.fromList(audioBlob.cast<int>()));
        } else if (audioBlob is List<int>) {
          _audioController.add(Uint8List.fromList(audioBlob));
        }
      }
    });

    _socket?.on('walkie:error', (data) {
      if (data is Map && data.containsKey('message')) {
        _errorController.add(data['message']);
      }
    });

    _socket?.connect();
  }

  void joinGroup(String groupId, int udpPort, String localIp, String? userName, String? userId) {
    _socket?.emit('walkie:join', {
      'groupId': groupId,
      'udpPort': udpPort,
      'localIp': localIp,
      'userName': userName,
      'userId': userId,
    });
  }

  void leaveGroup(String groupId) {
    _socket?.emit('walkie:leave', {'groupId': groupId});
  }

  void startPtt(String groupId, String senderName, String? senderId) {
    _socket?.emit('walkie:ptt_start', {
      'groupId': groupId,
      'senderName': senderName,
      'senderId': senderId,
    });
  }

  void sendChatMessage(String groupId, String senderName, String senderId, String message) {
    _socket?.emit('walkie:chat_message', {
      'groupId': groupId,
      'senderName': senderName,
      'senderId': senderId,
      'message': message,
    });
  }

  void stopPtt(String groupId, String senderName, String? senderId) {
    _socket?.emit('walkie:ptt_stop', {
      'groupId': groupId,
      'senderName': senderName,
      'senderId': senderId,
    });
  }

  void sendAudio(String groupId, String senderId, Uint8List audioData) {
    _socket?.emit('walkie:audio', {
      'groupId': groupId,
      'senderId': senderId,
      'audioBlob': audioData,
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _pttController.close();
    _onlineUsersController.close();
    _historyController.close();
    _errorController.close();
    _chatController.close();
    _chatHistoryController.close();
    _audioController.close();
  }
}
