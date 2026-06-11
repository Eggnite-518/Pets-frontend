import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pets/core/network/api_client.dart';

class OfficialMessageOrderRef {
  final String orderId;
  final String title;
  final String subtitle;

  const OfficialMessageOrderRef({
    required this.orderId,
    required this.title,
    required this.subtitle,
  });
}

class OfficialMessagePreview {
  final String orderId;
  final String title;
  final String subtitle;
  final String content;
  final String createdAt;
  final int messageCount;

  const OfficialMessagePreview({
    required this.orderId,
    required this.title,
    required this.subtitle,
    required this.content,
    required this.createdAt,
    required this.messageCount,
  });
}

class OfficialMessageItem {
  final int messageId;
  final String orderId;
  final String content;
  final String createdAt;

  const OfficialMessageItem({
    required this.messageId,
    required this.orderId,
    required this.content,
    required this.createdAt,
  });

  factory OfficialMessageItem.fromJson(Map<String, dynamic> json) {
    return OfficialMessageItem(
      messageId: _toInt(json['messageId']),
      orderId: json['orderId']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class OfficialMessageInboxRepository {
  final ApiClient _apiClient;

  const OfficialMessageInboxRepository(this._apiClient);

  Future<List<OfficialMessagePreview>> loadPreviews(
    List<OfficialMessageOrderRef> orders,
  ) async {
    final uniqueOrders = <String, OfficialMessageOrderRef>{};
    for (final order in orders) {
      final orderId = order.orderId.trim();
      if (orderId.isEmpty) {
        continue;
      }
      uniqueOrders.putIfAbsent(orderId, () => order);
    }

    final previews = await Future.wait(
      uniqueOrders.values.map(_loadOrderPreview),
    );
    final values = previews.whereType<OfficialMessagePreview>().toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return values;
  }

  Future<List<OfficialMessageItem>> loadOrderMessages(String orderId) async {
    if (orderId.trim().isEmpty) {
      return const [];
    }
    final response = await _apiClient.get<List<OfficialMessageItem>>(
      path: '/api/v1/messages/official?orderId=$orderId',
      dataParser: (data) {
        final list = data as List? ?? const [];
        return list
            .whereType<Map>()
            .map(
              (item) =>
                  OfficialMessageItem.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      },
    );
    final messages = response.data ?? const <OfficialMessageItem>[];
    final sorted = messages.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  Future<OfficialMessagePreview?> _loadOrderPreview(
    OfficialMessageOrderRef order,
  ) async {
    try {
      final messages = await loadOrderMessages(order.orderId);
      if (messages.isEmpty) {
        return null;
      }
      final latest = messages.first;
      return OfficialMessagePreview(
        orderId: order.orderId,
        title: order.title,
        subtitle: order.subtitle,
        content: latest.content,
        createdAt: latest.createdAt,
        messageCount: messages.length,
      );
    } catch (_) {
      return null;
    }
  }
}

class OfficialMessagesInboxScreen extends StatefulWidget {
  final bool isCaretaker;
  final List<OfficialMessageOrderRef> orders;
  final List<OfficialMessagePreview> initialPreviews;

  const OfficialMessagesInboxScreen({
    super.key,
    required this.isCaretaker,
    required this.orders,
    this.initialPreviews = const [],
  });

  @override
  State<OfficialMessagesInboxScreen> createState() =>
      _OfficialMessagesInboxScreenState();
}

class _OfficialMessagesInboxScreenState
    extends State<OfficialMessagesInboxScreen> {
  late final OfficialMessageInboxRepository _repository;

  List<OfficialMessagePreview> _previews = const [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = OfficialMessageInboxRepository(ApiClient());
    _previews = widget.initialPreviews;
    _isLoading = widget.initialPreviews.isEmpty;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _errorMessage = null;
      if (_previews.isEmpty) {
        _isLoading = true;
      }
    });

    try {
      final previews = await _repository.loadPreviews(widget.orders);
      if (!mounted) {
        return;
      }
      setState(() {
        _previews = previews;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = '加载官方消息失败，请稍后重试';
        _isLoading = false;
      });
    }
  }

  void _openOrder(OfficialMessagePreview preview) {
    final path = widget.isCaretaker
        ? '/caretaker/order/${preview.orderId}'
        : '/order/${preview.orderId}';
    context.push(path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '官方消息',
          style: TextStyle(
            color: Color(0xFF1A2621),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF004D36),
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: 420,
          child: Center(
            child: CircularProgressIndicator(color: Color(0xFF004D36)),
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
                  TextButton(onPressed: _load, child: const Text('重试')),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_previews.isEmpty) {
      return LayoutBuilder(
        builder: (_, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: constraints.maxHeight,
            child: const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  '暂无官方消息\n异常提醒、系统通知会汇总展示在这里',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF8BA49A),
                    height: 1.7,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5ECE8)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_user_outlined, color: Color(0xFF004D36)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '平台官方账号发送的异常提醒、履约保护通知和系统状态变更，都会集中显示在这里。',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF5A6B62),
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ..._previews.map(
          (preview) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _OfficialMessagePreviewCard(
              preview: preview,
              onTap: () => _openOrder(preview),
            ),
          ),
        ),
      ],
    );
  }
}

class _OfficialMessagePreviewCard extends StatelessWidget {
  final OfficialMessagePreview preview;
  final VoidCallback onTap;

  const _OfficialMessagePreviewCard({
    required this.preview,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = preview.subtitle.isNotEmpty
        ? preview.subtitle
        : '订单 #${preview.orderId}';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE5ECE8)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F2EF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  color: Color(0xFF004D36),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preview.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A2621),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          preview.createdAt,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8BA49A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8BA49A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      preview.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF43574E),
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F7F5),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '共 ${preview.messageCount} 条通知',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF5A6B62),
                            ),
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          '查看订单',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF004D36),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right,
                          color: Color(0xFF004D36),
                          size: 18,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

int _toInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
