/// 发送方角色：1=宠主，2=宠托师
class ChatMessage {
  final String messageId;
  final int senderRole;
  final String content;
  final String sentAt;

  const ChatMessage({
    required this.messageId,
    required this.senderRole,
    required this.content,
    required this.sentAt,
  });

  bool get isMine => senderRole == 2;
}
