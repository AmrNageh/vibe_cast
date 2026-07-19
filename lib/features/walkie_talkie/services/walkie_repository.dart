import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import '../models/walkie_group_entity.dart';

@lazySingleton
class WalkieRepository {
  final Dio _dio;
  
  String? _token;
  late final String userId;
  late final String userName;

  WalkieRepository() : _dio = Dio(BaseOptions(
    baseUrl: 'http://192.168.1.6:4000/api',
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
    // Generate an anonymous user for the standalone VibeCast backend
    userId = 'user-${DateTime.now().millisecondsSinceEpoch}';
    userName = 'Agent-${userId.substring(userId.length - 4)}';
  }

  Future<void> login(String email, String password) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      _token = response.data['accessToken'];
      userId = response.data['user']['id'];
      userName = response.data['user']['name'];
    } catch (e) {
      debugPrint('WalkieRepository login error: $e');
      // If login fails, we might still try to fetch if backend allows it
    }
  }

  Future<List<WalkieGroupEntity>> getGroups() async {
    try {
      final response = await _dio.get('/walkie/groups');
      final List<dynamic> data = response.data['data'] ?? response.data;
      
      return data.map((json) => WalkieGroupEntity(
        id: json['_id'] ?? json['id'] ?? '',
        name: json['name'] ?? 'Unknown Group',
        memberCount: (json['members'] as List?)?.length ?? 0,
      )).toList();
    } catch (e) {
      throw Exception('Failed to fetch groups: $e');
    }
  }

  Future<WalkieGroupEntity> createGroup(String name, String description) async {
    try {
      final response = await _dio.post('/walkie/groups', data: {
        'name': name,
        'description': description,
      });
      final json = response.data['data'];
      return WalkieGroupEntity(
        id: json['id'] ?? '',
        name: json['name'] ?? 'Unknown Group',
        memberCount: 0,
      );
    } catch (e) {
      throw Exception('Failed to create group: $e');
    }
  }
}
