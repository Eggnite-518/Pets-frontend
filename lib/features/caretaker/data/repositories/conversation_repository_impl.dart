import 'package:pets/core/network/api_exception.dart';
import 'package:pets/core/network/api_result.dart';

import '../../domain/entities/chat_message.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/conversation_repository.dart';
import '../datasources/conversation_remote_data_source.dart';

class ConversationRepositoryImpl implements ConversationRepository {
  final ConversationRemoteDataSource _remoteDataSource;

  const ConversationRepositoryImpl(this._remoteDataSource);

  @override
  Future<ApiResult<List<Conversation>>> getConversations() async {
    try {
      final response = await _remoteDataSource.getConversations();
      final list = response.data ?? [];
      return ApiSuccess(list.map((m) => m.toEntity()).toList());
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('获取消息列表失败', cause: e));
    }
  }

  @override
  Future<ApiResult<List<ChatMessage>>> getMessages({
    required String conversationId,
    String? peerId,
  }) async {
    try {
      final response = await _remoteDataSource.getMessages(
        conversationId: conversationId,
        peerId: peerId,
      );
      final list = response.data ?? [];
      return ApiSuccess(list.map((m) => m.toEntity()).toList());
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('获取聊天记录失败', cause: e));
    }
  }

  @override
  Future<ApiResult<ChatMessage>> sendMessage({
    required String conversationId,
    required String content,
    String? peerId,
  }) async {
    try {
      final response = await _remoteDataSource.sendMessage(
        conversationId: conversationId,
        content: content,
        peerId: peerId,
      );
      final data = response.data;
      if (data == null) {
        return const ApiFailure(ApiException('发送失败'));
      }
      return ApiSuccess(data.toEntity());
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('发送消息失败', cause: e));
    }
  }
}
