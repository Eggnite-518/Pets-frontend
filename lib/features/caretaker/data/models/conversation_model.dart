import '../../domain/entities/conversation.dart';
import 'package:pets/core/utils/image_url_helper.dart';

class ConversationModel extends Conversation {
  const ConversationModel({
    required super.conversationId,
    required super.orderId,
    super.peerId,
    required super.peerName,
    required super.peerAvatarUrl,
    required super.petName,
    required super.lastMessagePreview,
    required super.lastMessageTimeText,
    required super.unreadCount,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      conversationId: json['conversationId']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      peerId: json['peerId']?.toString() ?? '',
      peerName: json['peerName']?.toString() ?? '',
      peerAvatarUrl: normalizeRemoteImageUrl(json['peerAvatarUrl']?.toString()),
      petName: json['petName']?.toString() ?? '',
      lastMessagePreview: json['lastMessagePreview']?.toString() ?? '',
      lastMessageTimeText: json['lastMessageTimeText']?.toString() ?? '',
      unreadCount: _asInt(json['unreadCount']),
    );
  }

  Conversation toEntity() => Conversation(
        conversationId: conversationId,
        orderId: orderId,
        peerId: peerId,
        peerName: peerName,
        peerAvatarUrl: peerAvatarUrl,
        petName: petName,
        lastMessagePreview: lastMessagePreview,
        lastMessageTimeText: lastMessageTimeText,
        unreadCount: unreadCount,
      );

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
