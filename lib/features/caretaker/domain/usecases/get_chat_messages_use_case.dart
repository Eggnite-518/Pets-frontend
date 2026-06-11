import 'package:pets/core/network/api_result.dart';

import '../entities/chat_message.dart';
import '../repositories/conversation_repository.dart';

class GetChatMessagesUseCase {
  final ConversationRepository _repository;

  const GetChatMessagesUseCase(this._repository);

  Future<ApiResult<List<ChatMessage>>> call({
    required String conversationId,
    String? peerId,
  }) {
    return _repository.getMessages(
      conversationId: conversationId,
      peerId: peerId,
    );
  }
}
