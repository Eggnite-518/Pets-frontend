import 'package:pets/core/network/api_client.dart';
import 'package:pets/core/network/api_response.dart';

import '../models/chat_message_model.dart';
import '../models/conversation_model.dart';

enum ConversationApiScope { caretaker, owner }

class ConversationRemoteDataSource {
  final ApiClient _apiClient;
  final ConversationApiScope scope;

  const ConversationRemoteDataSource(
    this._apiClient, {
    this.scope = ConversationApiScope.caretaker,
  });

  String get _conversationListPath => switch (scope) {
    ConversationApiScope.caretaker => '/api/v1/caretaker/me/conversations',
    ConversationApiScope.owner => '/api/v1/owner/me/conversations',
  };

  String _messagesPath(String conversationId) => switch (scope) {
    ConversationApiScope.caretaker =>
      '/api/v1/caretaker/conversations/$conversationId/messages',
    ConversationApiScope.owner =>
      '/api/v1/owner/conversations/$conversationId/messages',
  };

  Future<ApiResponse<List<ConversationModel>>> getConversations() {
    return _apiClient.get<List<ConversationModel>>(
      path: _conversationListPath,
      dataParser: (data) {
        final list = data as List;
        return list
            .map(
              (e) => ConversationModel.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
      },
    );
  }

  Future<ApiResponse<List<ChatMessageModel>>> getMessages({
    required String conversationId,
    String? peerId,
  }) {
    var path = _messagesPath(conversationId);
    if (peerId != null && peerId.isNotEmpty) {
      path = '$path?peerId=$peerId';
    }
    return _apiClient.get<List<ChatMessageModel>>(
      path: path,
      dataParser: (data) {
        final list = data as List;
        return list
            .map(
              (e) => ChatMessageModel.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
      },
    );
  }

  Future<ApiResponse<ChatMessageModel>> sendMessage({
    required String conversationId,
    required String content,
    String? peerId,
  }) {
    final body = <String, dynamic>{'content': content};
    if (scope == ConversationApiScope.owner &&
        peerId != null &&
        peerId.isNotEmpty) {
      body['peerId'] = int.tryParse(peerId) ?? peerId;
    }
    return _apiClient.post<ChatMessageModel>(
      path: _messagesPath(conversationId),
      body: body,
      dataParser: (data) {
        final json = Map<String, dynamic>.from(data as Map);
        return ChatMessageModel.fromJson(json);
      },
    );
  }
}
