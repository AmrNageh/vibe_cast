import 'package:equatable/equatable.dart';

class ChatMessageEntity extends Equatable {
  final String senderId;
  final String senderName;
  final String text;
  final String timestamp;

  const ChatMessageEntity({
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
  });

  factory ChatMessageEntity.fromJson(Map<String, dynamic> json) {
    return ChatMessageEntity(
      senderId: json['senderId']?.toString() ?? '',
      senderName: json['senderName']?.toString() ?? 'Unknown',
      text: json['text']?.toString() ?? '',
      timestamp: json['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': timestamp,
    };
  }

  @override
  List<Object?> get props => [senderId, senderName, text, timestamp];
}
