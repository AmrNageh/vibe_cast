import 'package:equatable/equatable.dart';

class WalkieGroupEntity extends Equatable {
  final String id;
  final String name;
  final int memberCount;

  const WalkieGroupEntity({
    required this.id,
    required this.name,
    required this.memberCount,
  });

  factory WalkieGroupEntity.fromJson(Map<String, dynamic> json) {
    return WalkieGroupEntity(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      memberCount: (json['members'] as List?)?.length ?? json['memberCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'memberCount': memberCount,
    };
  }

  WalkieGroupEntity copyWith({
    String? id,
    String? name,
    int? memberCount,
  }) {
    return WalkieGroupEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      memberCount: memberCount ?? this.memberCount,
    );
  }

  @override
  List<Object?> get props => [id, name, memberCount];
}
