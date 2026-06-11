import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pets/core/auth/auth_token_store.dart';
import 'package:pets/core/network/api_client.dart';
import 'package:pets/core/utils/image_url_helper.dart';

import '../../caretaker/data/datasources/conversation_remote_data_source.dart';
import '../../caretaker/data/repositories/conversation_repository_impl.dart';
import '../../caretaker/domain/entities/chat_message.dart';
import '../../caretaker/domain/usecases/get_chat_messages_use_case.dart';
import '../../caretaker/domain/usecases/send_chat_message_use_case.dart';

class OwnerChatScreen extends StatefulWidget {
  const OwnerChatScreen({
    super.key,
    required this.conversationId,
    required this.peerName,
    this.peerAvatarUrl = '',
    this.peerId = '',
    this.petName,
    this.orderId,
  });

  final String conversationId;
  final String peerName;
  final String peerAvatarUrl;
  final String peerId;
  final String? petName;
  final String? orderId;

  @override
  State<OwnerChatScreen> createState() => _OwnerChatScreenState();
}

class _OwnerChatScreenState extends State<OwnerChatScreen> {
  late final GetChatMessagesUseCase _getChatMessagesUseCase;
  late final SendChatMessageUseCase _sendChatMessageUseCase;

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;
  String _myNickname = '';
  String _myAvatarUrl = '';
  String _peerAvatarUrl = '';
  Timer? _pollTimer;

  String? get _peerId =>
      widget.peerId.isNotEmpty ? widget.peerId : null;

  @override
  void initState() {
    super.initState();
    final client = ApiClient();
    final dataSource = ConversationRemoteDataSource(
      client,
      scope: ConversationApiScope.owner,
    );
    final repo = ConversationRepositoryImpl(dataSource);
    _getChatMessagesUseCase = GetChatMessagesUseCase(repo);
    _sendChatMessageUseCase = SendChatMessageUseCase(repo);
    AuthTokenStore.instance.readNickname().then((nickname) {
      if (mounted && nickname != null) {
        setState(() => _myNickname = nickname);
      }
    });
    _peerAvatarUrl = normalizeRemoteImageUrl(widget.peerAvatarUrl);
    _loadAvatars();
    _loadMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_isSending && mounted) {
        _loadMessages(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAvatars() async {
    final client = ApiClient();
    try {
      final ownerResponse = await client.get<Map<String, dynamic>>(
        path: '/api/v1/me/pet-owner',
        dataParser: (data) => Map<String, dynamic>.from(data as Map),
      );
      if (ownerResponse.isSuccess && ownerResponse.data != null) {
        final avatar = normalizeRemoteImageUrl(
          ownerResponse.data!['avatarUrl']?.toString(),
        );
        final nickname = ownerResponse.data!['nickname']?.toString() ?? '';
        if (mounted) {
          setState(() {
            if (avatar.isNotEmpty) {
              _myAvatarUrl = avatar;
            }
            if (nickname.isNotEmpty) {
              _myNickname = nickname;
            }
          });
        }
      }
    } catch (_) {}

    final peerId = _peerId;
    if (peerId == null || widget.conversationId.isEmpty) {
      return;
    }

    try {
      final peerResponse = await client.get<Map<String, dynamic>>(
        path:
            '/api/v1/orders/${widget.conversationId}/reservations/$peerId',
        dataParser: (data) => Map<String, dynamic>.from(data as Map),
      );
      if (!peerResponse.isSuccess || peerResponse.data == null || !mounted) {
        return;
      }
      final avatar = normalizeRemoteImageUrl(
        peerResponse.data!['providerAvatarUrl']?.toString(),
      );
      if (avatar.isEmpty) {
        return;
      }
      setState(() => _peerAvatarUrl = avatar);
    } catch (_) {}
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final result = await _getChatMessagesUseCase(
      conversationId: widget.conversationId,
      peerId: _peerId,
    );
    if (!mounted) return;

    result.when(
      success: (messages) {
        setState(() {
          _messages = messages;
          if (!silent) _isLoading = false;
        });
        _scrollToBottom();
      },
      failure: (error) {
        if (silent) return;
        setState(() {
          _errorMessage = error.message;
          _isLoading = false;
        });
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final content = _textController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _textController.clear();

    final result = await _sendChatMessageUseCase(
      conversationId: widget.conversationId,
      content: content,
      peerId: _peerId,
    );
    if (!mounted) return;

    result.when(
      success: (message) {
        setState(() {
          _messages = [..._messages, message];
          _isSending = false;
        });
        _scrollToBottom();
      },
      failure: (error) {
        setState(() => _isSending = false);
        _textController.text = content;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message), backgroundColor: Colors.red),
        );
      },
    );
  }

  String get _appBarSubtitle {
    if (widget.petName != null && widget.petName!.isNotEmpty) {
      return '订单 · ${widget.petName}';
    }
    if (widget.orderId != null && widget.orderId!.isNotEmpty) {
      return '订单 #${widget.orderId}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A2621)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.peerName.isNotEmpty ? widget.peerName : '聊天',
              style: const TextStyle(
                color: Color(0xFF1A2621),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_appBarSubtitle.isNotEmpty)
              Text(
                _appBarSubtitle,
                style: const TextStyle(
                  color: Color(0xFF8BA49A),
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF004D36)),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _errorMessage!,
              style: const TextStyle(color: Color(0xFF8BA49A)),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: () => _loadMessages(), child: const Text('重试')),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return const Center(
        child: Text(
          '还没有消息，发一句打个招呼吧',
          style: TextStyle(fontSize: 14, color: Color(0xFF8BA49A)),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (_, index) => _OwnerMessageBubble(
        message: _messages[index],
        peerName: widget.peerName,
        peerAvatarUrl: _peerAvatarUrl,
        myNickname: _myNickname,
        myAvatarUrl: _myAvatarUrl,
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: '输入消息...',
                hintStyle: const TextStyle(color: Color(0xFFC3D5CC)),
                filled: true,
                fillColor: const Color(0xFFF7F9F8),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _isSending ? null : _sendMessage,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF004D36),
              disabledBackgroundColor: const Color(0xFFC3D5CC),
            ),
            icon: _isSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}

class _OwnerMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final String peerName;
  final String peerAvatarUrl;
  final String myNickname;
  final String myAvatarUrl;

  const _OwnerMessageBubble({
    required this.message,
    required this.peerName,
    required this.peerAvatarUrl,
    required this.myNickname,
    required this.myAvatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final isMine = message.senderRole == 1;
    final bubbleColor = isMine ? const Color(0xFF004D36) : Colors.white;
    final textColor = isMine ? Colors.white : const Color(0xFF1A2621);
    final avatar = isMine ? _buildMyAvatar() : _buildPeerAvatar();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[avatar, const SizedBox(width: 8)],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMine ? 16 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 16),
                ),
                border: isMine
                    ? null
                    : Border.all(color: const Color(0xFFEBEBEB)),
              ),
              child: Column(
                crossAxisAlignment: isMine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 15,
                      color: textColor,
                      height: 1.4,
                    ),
                  ),
                  if (message.sentAt.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(message.sentAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: isMine
                            ? Colors.white.withValues(alpha: 0.7)
                            : const Color(0xFF8BA49A),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isMine) ...[const SizedBox(width: 8), avatar],
        ],
      ),
    );
  }

  Widget _buildMyAvatar() {
    if (myAvatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundImage: NetworkImage(myAvatarUrl),
        backgroundColor: const Color(0xFFE8F2EF),
      );
    }
    return _buildInitialAvatar(
      myNickname,
      const Color(0xFFE8F2EF),
      const Color(0xFF004D36),
    );
  }

  Widget _buildPeerAvatar() {
    if (peerAvatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundImage: NetworkImage(peerAvatarUrl),
        backgroundColor: const Color(0xFFE8F2EF),
      );
    }
    return _buildInitialAvatar(
      peerName,
      const Color(0xFFE8F2EF),
      const Color(0xFF004D36),
    );
  }

  Widget _buildInitialAvatar(String name, Color bg, Color fg) {
    final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
    return CircleAvatar(
      radius: 18,
      backgroundColor: bg,
      child: Text(
        initial,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  String _formatTime(String sentAt) {
    if (sentAt.length >= 16) return sentAt.substring(11, 16);
    return sentAt;
  }
}
