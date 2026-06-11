import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pets/core/network/api_client.dart';
import 'package:pets/features/messages/official_messages_support.dart';

import '../data/datasources/conversation_remote_data_source.dart';
import '../data/repositories/conversation_repository_impl.dart';
import '../domain/entities/conversation.dart';
import '../domain/usecases/get_conversations_use_case.dart';

class CaretakerMessagesScreen extends StatefulWidget {
  const CaretakerMessagesScreen({super.key});

  @override
  State<CaretakerMessagesScreen> createState() =>
      _CaretakerMessagesScreenState();
}

class _CaretakerMessagesScreenState extends State<CaretakerMessagesScreen> {
  late final GetConversationsUseCase _getConversationsUseCase;
  late final OfficialMessageInboxRepository _officialMessageRepository;

  List<Conversation> _conversations = [];
  List<OfficialMessagePreview> _officialPreviews = const [];
  List<OfficialMessageOrderRef> _officialOrders = const [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final client = ApiClient();
    final dataSource = ConversationRemoteDataSource(client);
    final repo = ConversationRepositoryImpl(dataSource);
    _officialMessageRepository = OfficialMessageInboxRepository(client);
    _getConversationsUseCase = GetConversationsUseCase(repo);
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _getConversationsUseCase();
    if (!mounted) return;

    final conversations = result.when<List<Conversation>?>(
      success: (data) => data,
      failure: (error) {
        setState(() {
          _errorMessage = error.message;
          _isLoading = false;
        });
        return null;
      },
    );
    if (conversations == null) {
      return;
    }

    final previews = await _loadOfficialPreviews(conversations);
    if (!mounted) return;
    final officialOrders = _officialMessageRepository.mergeOrderRefs(
      _buildOfficialMessageOrders(conversations),
      previews,
    );
    setState(() {
      _conversations = conversations;
      _officialPreviews = previews;
      _officialOrders = officialOrders;
      _isLoading = false;
    });
  }

  Future<List<OfficialMessagePreview>> _loadOfficialPreviews(
    List<Conversation> conversations,
  ) async {
    try {
      return await _officialMessageRepository.loadPreviews(
        _buildOfficialMessageOrders(conversations),
      );
    } catch (_) {
      return const [];
    }
  }

  void _openChat(Conversation conversation) {
    final query = {
      'peerName': conversation.peerName,
      if (conversation.peerAvatarUrl.isNotEmpty)
        'peerAvatarUrl': conversation.peerAvatarUrl,
      if (conversation.petName.isNotEmpty) 'petName': conversation.petName,
      if (conversation.orderId.isNotEmpty) 'orderId': conversation.orderId,
    };
    final uri = Uri(
      path: '/caretaker/messages/${conversation.conversationId}',
      queryParameters: query,
    );
    context.push(uri.toString()).then((_) {
      if (mounted) _loadConversations();
    });
  }

  void _openOfficialMessages() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OfficialMessagesInboxScreen(
          isCaretaker: true,
          orders: _officialOrders,
          initialPreviews: _officialPreviews,
        ),
      ),
    );
  }

  List<OfficialMessageOrderRef> _buildOfficialMessageOrders(
    List<Conversation> conversations,
  ) {
    final deduped = <String, OfficialMessageOrderRef>{};
    for (final conversation in conversations) {
      final orderId = conversation.orderId.trim();
      if (orderId.isEmpty) {
        continue;
      }
      final title = conversation.petName.isNotEmpty
          ? '${conversation.petName} 的服务通知'
          : '订单 #$orderId';
      final subtitle = conversation.peerName.isNotEmpty
          ? '宠主 · ${conversation.peerName}'
          : '订单 #$orderId';
      deduped.putIfAbsent(
        orderId,
        () => OfficialMessageOrderRef(
          orderId: orderId,
          title: title,
          subtitle: subtitle,
        ),
      );
    }
    return deduped.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          '消息',
          style: TextStyle(
            color: Color(0xFF1A2621),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _OfficialMessagesButton(
              hasUpdates: _officialPreviews.isNotEmpty,
              onTap: _openOfficialMessages,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF004D36),
        onRefresh: _loadConversations,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return LayoutBuilder(
        builder: (_, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: 400,
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF004D36)),
            ),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return LayoutBuilder(
        builder: (_, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: constraints.maxHeight,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Color(0xFF8BA49A)),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loadConversations,
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_conversations.isEmpty) {
      return LayoutBuilder(
        builder: (_, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: constraints.maxHeight,
            child: const Center(
              child: Text(
                '暂无消息',
                style: TextStyle(fontSize: 15, color: Color(0xFF8BA49A)),
              ),
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _conversations.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, thickness: 1, color: Color(0xFFF7F9F8)),
      itemBuilder: (_, index) {
        final conversation = _conversations[index];
        return _ConversationListItem(
          conversation: conversation,
          onTap: () => _openChat(conversation),
        );
      },
    );
  }
}

class _OfficialMessagesButton extends StatelessWidget {
  final bool hasUpdates;
  final VoidCallback onTap;

  const _OfficialMessagesButton({
    required this.hasUpdates,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '官方消息',
      onPressed: onTap,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(
            Icons.notifications_none_rounded,
            color: Color(0xFF1A2621),
          ),
          if (hasUpdates)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: const Color(0xFFF06A42),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: Colors.white, width: 1.6),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ConversationListItem extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;

  const _ConversationListItem({
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unreadCount = conversation.unreadCount;
    final bgColor = unreadCount > 0 ? const Color(0xFFF2F8F5) : Colors.white;
    final displayName = conversation.peerName.isNotEmpty
        ? conversation.peerName
        : '宠主';
    final subtitle = conversation.petName.isNotEmpty
        ? '订单 · ${conversation.petName}'
        : (conversation.orderId.isNotEmpty
              ? '订单 #${conversation.orderId}'
              : null);

    return InkWell(
      onTap: onTap,
      child: Container(
        color: bgColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            SizedBox(
              width: 54,
              height: 54,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (conversation.peerAvatarUrl.isNotEmpty)
                    CircleAvatar(
                      radius: 25,
                      backgroundImage: NetworkImage(conversation.peerAvatarUrl),
                    )
                  else
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 0,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF06A42),
                          shape: BoxShape.circle,
                          border: Border.all(color: bgColor, width: 2),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A2621),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        conversation.lastMessageTimeText,
                        style: TextStyle(
                          fontSize: 13,
                          color: unreadCount > 0
                              ? const Color(0xFF004D36)
                              : const Color(0xFF999999),
                          fontWeight: unreadCount > 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8BA49A),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    conversation.lastMessagePreview.isNotEmpty
                        ? conversation.lastMessagePreview
                        : '暂无消息',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF5A6B62),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
