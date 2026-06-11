import 'package:pets/core/network/api_result.dart';

import '../entities/chat_message.dart';
import '../entities/conversation.dart';

abstract class ConversationRepository {
  Future<ApiResult<List<Conversation>>> getConversations();

  Future<ApiResult<List<ChatMessage>>> getMessages({
    required String conversationId,
    String? peerId,
  });

  Future<ApiResult<ChatMessage>> sendMessage({
    required String conversationId,
    required String content,
    String? peerId,
  });
}
