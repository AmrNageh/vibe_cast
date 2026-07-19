import 'package:equatable/equatable.dart';

class OnlineUserEntity extends Equatable {
  final String id;
  final String name;
  final bool isOnline;

  const OnlineUserEntity({
    required this.id,
    required this.name,
    required this.isOnline,
  });

  factory OnlineUserEntity.fromJson(Map<String, dynamic> json) {
    return OnlineUserEntity(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      isOnline: json['isOnline'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isOnline': isOnline,
    };
  }

  OnlineUserEntity copyWith({
    String? id,
    String? name,
    bool? isOnline,
  }) {
    return OnlineUserEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  @override
  List<Object?> get props => [id, name, isOnline];
}
