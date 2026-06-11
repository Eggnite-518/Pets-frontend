class Conversation {
  final String conversationId;
  final String orderId;
  final String peerId;
  final String peerName;
  final String peerAvatarUrl;
  final String petName;
  final String lastMessagePreview;
  final String lastMessageTimeText;
  final int unreadCount;

  const Conversation({
    required this.conversationId,
    required this.orderId,
    this.peerId = '',
    required this.peerName,
    required this.peerAvatarUrl,
    required this.petName,
    required this.lastMessagePreview,
    required this.lastMessageTimeText,
    required this.unreadCount,
  });
}
