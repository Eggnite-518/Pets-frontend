import 'package:pets/core/network/api_result.dart';

import '../entities/chat_message.dart';
import '../repositories/conversation_repository.dart';

class SendChatMessageUseCase {
  final ConversationRepository _repository;

  const SendChatMessageUseCase(this._repository);

  Future<ApiResult<ChatMessage>> call({
    required String conversationId,
    required String content,
    String? peerId,
  }) {
    return _repository.sendMessage(
      conversationId: conversationId,
      content: content,
      peerId: peerId,
    );
  }
}
