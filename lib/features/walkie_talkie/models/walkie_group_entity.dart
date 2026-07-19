import 'package:equatable/equatable.dart';

class WalkieGroupEntity extends Equatable {
  final String id;
  final String name;
  final bool isPrivate;
  final int memberCount;
  final List<String> permanentMembers;

  const WalkieGroupEntity({
    required this.id,
    required this.name,
    required this.isPrivate,
    required this.memberCount,
    this.permanentMembers = const [],
  });

  factory WalkieGroupEntity.fromJson(Map<String, dynamic> json) {
    return WalkieGroupEntity(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      isPrivate: json['isPrivate'] ?? false,
      memberCount: json['memberCount'] ?? 0,
      permanentMembers: json['permanentMembers'] != null ? List<String>.from(json['permanentMembers']) : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isPrivate': isPrivate,
      'memberCount': memberCount,
      'permanentMembers': permanentMembers,
    };
  }

  WalkieGroupEntity copyWith({
    String? id,
    String? name,
    bool? isPrivate,
    int? memberCount,
    List<String>? permanentMembers,
  }) {
    return WalkieGroupEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      isPrivate: isPrivate ?? this.isPrivate,
      memberCount: memberCount ?? this.memberCount,
      permanentMembers: permanentMembers ?? this.permanentMembers,
    );
  }

  @override
  List<Object?> get props => [id, name, isPrivate, memberCount, permanentMembers];
}
