import '../../domain/entities/chat_message.dart';

class ChatMessageModel extends ChatMessage {
  const ChatMessageModel({
    required super.messageId,
    required super.senderRole,
    required super.content,
    required super.sentAt,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      messageId: json['messageId']?.toString() ?? '',
      senderRole: _asInt(json['senderRole']),
      content: json['content']?.toString() ?? '',
      sentAt: json['sentAt']?.toString() ?? '',
    );
  }

  ChatMessage toEntity() => ChatMessage(
        messageId: messageId,
        senderRole: senderRole,
        content: content,
        sentAt: sentAt,
      );

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
