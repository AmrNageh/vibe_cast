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

class WalkieGroupJoinedByInvite extends WalkieTalkieEvent {
  final String inviteId;

  const WalkieGroupJoinedByInvite(this.inviteId);

  @override
  List<Object?> get props => [inviteId];
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
  final List<dynamic> history;
  const WalkieHistoryUpdated(this.history);
  @override
  List<Object?> get props => [history];
}

class WalkieChatHistoryUpdated extends WalkieTalkieEvent {
  final List<dynamic> chatHistory;
  const WalkieChatHistoryUpdated(this.chatHistory);
  @override
  List<Object?> get props => [chatHistory];
}

class WalkieChatMessageReceived extends WalkieTalkieEvent {
  final Map<String, dynamic> message;
  const WalkieChatMessageReceived(this.message);
  @override
  List<Object?> get props => [message];
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
  final List<dynamic> history;
  final List<dynamic> chatHistory;

  const WalkieTalkieInChannel({
    required this.group,
    this.status = TransmissionStatus.idle,
    this.activeTransmitterName,
    this.members = const [],
    this.history = const [],
    this.chatHistory = const [],
  });

  WalkieTalkieInChannel copyWith({
    WalkieGroupEntity? group,
    TransmissionStatus? status,
    String? activeTransmitterName,
    List<OnlineUserEntity>? members,
    List<dynamic>? history,
    List<dynamic>? chatHistory,
  }) {
    return WalkieTalkieInChannel(
      group: group ?? this.group,
      status: status ?? this.status,
      activeTransmitterName: activeTransmitterName ?? this.activeTransmitterName,
      members: members ?? this.members,
      history: history ?? this.history,
      chatHistory: chatHistory ?? this.chatHistory,
    );
  }

  @override
  List<Object?> get props => [group, status, activeTransmitterName, members, history, chatHistory];
}

class WalkieTalkieFailure extends WalkieTalkieState {
  final String message;
  const WalkieTalkieFailure(this.message);

  @override
  List<Object?> get props => [message];
}
