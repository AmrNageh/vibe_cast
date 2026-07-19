import 'package:equatable/equatable.dart';
import '../models/walkie_group_entity.dart';
import '../models/online_user_entity.dart';

abstract class WalkieTalkieEvent extends Equatable {
  const WalkieTalkieEvent();

  @override
  List<Object?> get props => [];
}

class WalkieInitialized extends WalkieTalkieEvent {}

class WalkieGroupsFetched extends WalkieTalkieEvent {}

class WalkieGroupCreated extends WalkieTalkieEvent {
  final String name;
  final List<String> memberIds;
  final bool isPrivate;

  const WalkieGroupCreated({
    required this.name,
    required this.memberIds,
    required this.isPrivate,
  });

  @override
  List<Object?> get props => [name, memberIds, isPrivate];
}

class WalkieGroupJoined extends WalkieTalkieEvent {
  final String groupId;
  const WalkieGroupJoined(this.groupId);

  @override
  List<Object?> get props => [groupId];
}

class WalkieGroupLeft extends WalkieTalkieEvent {
  final String groupId;
  const WalkieGroupLeft(this.groupId);

  @override
  List<Object?> get props => [groupId];
}

class WalkieChannelEntered extends WalkieTalkieEvent {
  final WalkieGroupEntity group;
  const WalkieChannelEntered(this.group);

  @override
  List<Object?> get props => [group];
}

class WalkiePTTPressed extends WalkieTalkieEvent {}

class WalkiePTTReleased extends WalkieTalkieEvent {}

class WalkieIncomingTransmission extends WalkieTalkieEvent {
  final String senderId;
  final String senderName;
  final String udpIp;
  final int udpPort;

  const WalkieIncomingTransmission({
    required this.senderId,
    required this.senderName,
    required this.udpIp,
    required this.udpPort,
  });

  @override
  List<Object?> get props => [senderId, senderName, udpIp, udpPort];
}

class WalkieOnlineUsersUpdated extends WalkieTalkieEvent {
  final List<OnlineUserEntity> onlineUsers;
  const WalkieOnlineUsersUpdated(this.onlineUsers);

  @override
  List<Object?> get props => [onlineUsers];
}

class WalkieHistoryUpdated extends WalkieTalkieEvent {
  final List<Map<String, dynamic>> history;
  const WalkieHistoryUpdated(this.history);

  @override
  List<Object?> get props => [history];
}

class WalkieTransmissionEnded extends WalkieTalkieEvent {
  final String senderId;
  const WalkieTransmissionEnded(this.senderId);

  @override
  List<Object?> get props => [senderId];
}

class WalkieCodecToggled extends WalkieTalkieEvent {
  final bool useOpus;
  const WalkieCodecToggled(this.useOpus);

  @override
  List<Object?> get props => [useOpus];
}

enum TransmissionStatus { idle, transmitting, receiving }

abstract class WalkieTalkieState extends Equatable {
  const WalkieTalkieState();

  @override
  List<Object?> get props => [];
}

class WalkieTalkieInitial extends WalkieTalkieState {}

class WalkieTalkieLoading extends WalkieTalkieState {}

class WalkieTalkieGroupsLoaded extends WalkieTalkieState {
  final List<WalkieGroupEntity> groups;
  final List<OnlineUserEntity> onlineUsers;
  final bool useOpus;

  const WalkieTalkieGroupsLoaded({
    required this.groups,
    required this.onlineUsers,
    this.useOpus = true,
  });

  @override
  List<Object?> get props => [groups, onlineUsers, useOpus];
}

class WalkieTalkieInChannel extends WalkieTalkieState {
  final WalkieGroupEntity group;
  final TransmissionStatus status;
  final String? activeTransmitterName;
  final List<OnlineUserEntity> members;
  final List<Map<String, dynamic>> history;

  const WalkieTalkieInChannel({
    required this.group,
    this.status = TransmissionStatus.idle,
    this.activeTransmitterName,
    this.members = const [],
    this.history = const [],
  });

  WalkieTalkieInChannel copyWith({
    WalkieGroupEntity? group,
    TransmissionStatus? status,
    String? activeTransmitterName,
    List<OnlineUserEntity>? members,
    List<Map<String, dynamic>>? history,
  }) {
    return WalkieTalkieInChannel(
      group: group ?? this.group,
      status: status ?? this.status,
      activeTransmitterName: activeTransmitterName ?? this.activeTransmitterName,
      members: members ?? this.members,
      history: history ?? this.history,
    );
  }

  @override
  List<Object?> get props => [group, status, activeTransmitterName, members, history];
}

class WalkieTalkieFailure extends WalkieTalkieState {
  final String message;
  const WalkieTalkieFailure(this.message);

  @override
  List<Object?> get props => [message];
}
