import 'package:pets/core/network/api_result.dart';

import '../entities/conversation.dart';
import '../repositories/conversation_repository.dart';

class GetConversationsUseCase {
  final ConversationRepository _repository;

  const GetConversationsUseCase(this._repository);

  Future<ApiResult<List<Conversation>>> call() {
    return _repository.getConversations();
  }
}
