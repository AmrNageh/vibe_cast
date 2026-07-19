import 'package:equatable/equatable.dart';

class ChatMessageEntity extends Equatable {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final String timestamp;

  const ChatMessageEntity({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
  });

  factory ChatMessageEntity.fromJson(Map<dynamic, dynamic> json) {
    return ChatMessageEntity(
      id: json['id']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      senderName: json['senderName']?.toString() ?? 'Unknown',
      text: json['message']?.toString() ?? '',
      timestamp: (DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now()).toIso8601String(),
    );
  }

  Map<dynamic, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': timestamp,
    };
  }

  @override
  List<Object?> get props => [id, senderId, senderName, text, timestamp];
}
