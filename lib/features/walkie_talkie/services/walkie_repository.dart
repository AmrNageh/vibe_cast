import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/config/app_config.dart';
import '../models/walkie_group_entity.dart';

@lazySingleton
class WalkieRepository {
  final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  String? _token;
  String _userId = '';
  String _userName = 'Unknown Node';
  bool isInitialized = false;

  String get userId => _userId;
  String get userName => _userName;

  WalkieRepository() : _dio = Dio(BaseOptions(
    baseUrl: AppConfig.serverUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        return handler.next(options);
      },
    ));
  }

  Future<void> initIdentity() async {
    if (isInitialized) return;
    String? storedId = await _storage.read(key: 'walkie_user_id');
    String? storedName = await _storage.read(key: 'walkie_user_name');

    if (storedId != null && storedId.isNotEmpty) {
      _userId = storedId;
      _userName = storedName ?? 'Unknown Node';
    } else {
      _userId = 'user-${DateTime.now().millisecondsSinceEpoch}';
      _userName = 'Unknown Node';
      await _storage.write(key: 'walkie_user_id', value: _userId);
    }
    isInitialized = true;
  }

  Future<void> setUserName(String name) async {
    _userName = name;
    await _storage.write(key: 'walkie_user_name', value: name);
  }

  Future<void> login(String email, String password) async {
    try {
      final response = await _dio.post('/api/auth/login', data: {
        'email': email,
        'password': password,
      });
      _token = response.data['accessToken'];
      _userId = response.data['user']['id'];
      _userName = response.data['user']['name'];
    } catch (e) {
      debugPrint('WalkieRepository login error: $e');
      // If login fails, we might still try to fetch if backend allows it
    }
  }

  Future<List<WalkieGroupEntity>> getGroups() async {
    try {
      final response = await _dio.get('/api/walkie/groups', queryParameters: {'userId': userId});
      final List<dynamic> data = response.data['data'] ?? response.data;
      
      return data.map((json) => WalkieGroupEntity.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch groups: $e');
    }
  }

  Future<WalkieGroupEntity> createGroup(String name, String description) async {
    try {
      final response = await _dio.post('/api/walkie/groups', data: {
        'name': name,
        'description': description,
        'userId': userId,
      });
      final json = response.data['data'];
      return WalkieGroupEntity.fromJson(json);
    } catch (e) {
      throw Exception('Failed to create group: $e');
    }
  }

  Future<WalkieGroupEntity> joinGroupFromInvite(String groupId) async {
    try {
      final response = await _dio.post('/api/walkie/groups/join', data: {
        'groupId': groupId,
        'userId': userId,
      });
      final json = response.data['data'];
      return WalkieGroupEntity.fromJson(json);
    } catch (e) {
      throw Exception('Failed to join group: $e');
    }
  }
}
