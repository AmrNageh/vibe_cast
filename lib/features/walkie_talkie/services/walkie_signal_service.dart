import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

@lazySingleton
class WalkieSignalService {
  io.Socket? _socket;
  
  final _pttStreamController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get pttStream => _pttStreamController.stream;

  final _onlineUsersController = StreamController<List<Map<String, dynamic>>>.broadcast();
  Stream<List<Map<String, dynamic>>> get onlineUsersStream => _onlineUsersController.stream;

  final _historyController = StreamController<List<Map<String, dynamic>>>.broadcast();
  Stream<List<Map<String, dynamic>>> get historyStream => _historyController.stream;

  final _errorController = StreamController<String>.broadcast();
  Stream<String> get errorStream => _errorController.stream;

  void connect(String serverUrl) {
    _socket = io.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket?.connect();

    _socket?.on('walkie:ptt_start', (data) {
      data['type'] = 'start';
      _pttStreamController.add(Map<String, dynamic>.from(data));
    });

    _socket?.on('walkie:ptt_stop', (data) {
      data['type'] = 'stop';
      _pttStreamController.add(Map<String, dynamic>.from(data));
    });
    
    _socket?.on('walkie:online_users', (data) {
      _onlineUsersController.add(List<Map<String, dynamic>>.from(data));
    });

    _socket?.on('walkie:history', (data) {
      _historyController.add(List<Map<String, dynamic>>.from(data));
    });

    _socket?.on('walkie:error', (data) {
      _errorController.add(data['message']?.toString() ?? 'Unknown error');
    });
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

  void stopPtt(String groupId, String senderName, String? senderId) {
    _socket?.emit('walkie:ptt_stop', {
      'groupId': groupId,
      'senderName': senderName,
      'senderId': senderId,
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
