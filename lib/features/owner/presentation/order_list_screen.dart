import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pets/core/network/api_client.dart';
import 'package:pets/core/network/api_exception.dart';
import 'package:pets/features/owner/data/datasources/review_remote_data_source.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  final ApiClient _apiClient = ApiClient();
  late final ReviewRemoteDataSource _reviewRemoteDataSource;

  bool _isLoading = true;
  String? _errorMessage;
  List<_OwnerOrder> _orders = const [];
  final Set<String> _reviewedOrderIds = {};

  @override
  void initState() {
    super.initState();
    _reviewRemoteDataSource = ReviewRemoteDataSource(_apiClient);
    _loadOrders();
  }

  @override
  void dispose() {
    _reviewRemoteDataSource.close();
    _apiClient.close();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiClient.get<List<_OwnerOrder>>(
        path: '/api/v1/orders/my',
        dataParser: (json) {
          final list = json as List<dynamic>;
          return list
              .map(
                (item) => _OwnerOrder.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList();
        },
      );

      if (!mounted) return;

      if (response.isSuccess) {
        final orders = response.data ?? const [];
        final reviewedOrderIds = await _loadReviewedOrderIds(orders);
        if (!mounted) return;

        setState(() {
          _orders = orders;
          _reviewedOrderIds
            ..clear()
            ..addAll(reviewedOrderIds);
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _errorMessage = response.message.isEmpty
            ? '加载订单失败'
            : response.message;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _openOrderDetail(String orderId) async {
    await context.push('/order/$orderId');
    if (!mounted) return;
    await _loadOrders();
  }

  Future<void> _openOrderReview(String orderId) async {
    final submitted = await context.push<bool>('/order/$orderId/review');
    if (submitted == true) {
      setState(() => _reviewedOrderIds.add(orderId));
      await _loadOrders();
    }
  }

  Future<Set<String>> _loadReviewedOrderIds(List<_OwnerOrder> orders) async {
    final completedOrders = orders.where((order) => order.canReview).toList();
    if (completedOrders.isEmpty) return <String>{};

    final reviewedIds = await Future.wait(
      completedOrders.map((order) async {
        try {
          final response = await _reviewRemoteDataSource.getRating(
            orderId: order.orderId,
          );
          return response.data == null ? null : order.orderId;
        } catch (_) {
          return null;
        }
      }),
    );

    return reviewedIds.whereType<String>().toSet();
  }

  List<_OwnerOrder> get _actionRequiredOrders {
    final pending = _orders.where((order) => order.needsOwnerAction).toList();
    pending.sort((a, b) {
      final priorityCompare = a.actionPriority.compareTo(b.actionPriority);
      if (priorityCompare != 0) return priorityCompare;
      return a.serviceDate.compareTo(b.serviceDate);
    });
    return pending;
  }

  List<_OwnerOrder> get _regularOrders {
    final actionIds = _actionRequiredOrders.map((order) => order.orderId).toSet();
    final regular = _orders
        .where((order) => !actionIds.contains(order.orderId))
        .toList();
    regular.sort((a, b) => b.serviceDate.compareTo(a.serviceDate));
    return regular;
  }

  @override
  Widget build(BuildContext context) {
    final actionOrders = _actionRequiredOrders;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F5),
      appBar: AppBar(
        title: const Text(
          '订单',
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadOrders,
        color: const Color(0xFF005A40),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            _HeaderSummary(
              totalCount: _orders.length,
              actionCount: actionOrders.length,
            ),
            const SizedBox(height: 16),
            if (!_isLoading &&
                _errorMessage == null &&
                actionOrders.isNotEmpty) ...[
              _ActionRequiredSection(
                orders: actionOrders,
                reviewedOrderIds: _reviewedOrderIds,
                onTap: _openOrderDetail,
                onReview: _openOrderReview,
              ),
              const SizedBox(height: 16),
            ],
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 120),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF005A40)),
                ),
              )
            else if (_errorMessage != null)
              _StatePanel(
                icon: Icons.error_outline,
                title: '加载失败',
                message: _errorMessage!,
                actionText: '重试',
                onAction: _loadOrders,
              )
            else if (_orders.isEmpty)
              const _StatePanel(
                icon: Icons.inbox_outlined,
                title: '暂无订单',
                message: '还没有相关订单',
              )
            else if (_regularOrders.isEmpty && actionOrders.isNotEmpty)
              const SizedBox.shrink()
            else ...[
              if (_regularOrders.isNotEmpty && actionOrders.isNotEmpty) ...[
                const Text(
                  '全部订单',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0B2A1F),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              ..._regularOrders.expand(
                (order) => [
                  _OwnerOrderCard(
                    order: order,
                    reviewed: _reviewedOrderIds.contains(order.orderId),
                    highlighted: false,
                    onTap: () => _openOrderDetail(order.orderId),
                    onReview: () => _openOrderReview(order.orderId),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeaderSummary extends StatelessWidget {
  final int totalCount;
  final int actionCount;

  const _HeaderSummary({required this.totalCount, required this.actionCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFE4EFE9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD2E2DA)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFF005A40),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.list_alt_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '我的订单',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0B2A1F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  actionCount > 0
                      ? '$totalCount 个订单 · $actionCount 个待你处理'
                      : '$totalCount 个订单',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF49625B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRequiredSection extends StatelessWidget {
  final List<_OwnerOrder> orders;
  final Set<String> reviewedOrderIds;
  final void Function(String orderId) onTap;
  final void Function(String orderId) onReview;

  const _ActionRequiredSection({
    required this.orders,
    required this.reviewedOrderIds,
    required this.onTap,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.notifications_active_outlined,
              size: 18,
              color: Color(0xFFC97C22),
            ),
            SizedBox(width: 6),
            Text(
              '待你处理',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0B2A1F),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          '以下订单需要你尽快操作',
          style: TextStyle(fontSize: 13, color: Color(0xFF5A6B62)),
        ),
        const SizedBox(height: 12),
        ...orders.map(
          (order) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _OwnerOrderCard(
              order: order,
              reviewed: reviewedOrderIds.contains(order.orderId),
              highlighted: true,
              onTap: () => onTap(order.orderId),
              onReview: () => onReview(order.orderId),
            ),
          ),
        ),
      ],
    );
  }
}

class _OwnerOrderCard extends StatelessWidget {
  final _OwnerOrder order;
  final bool reviewed;
  final bool highlighted;
  final VoidCallback onTap;
  final VoidCallback onReview;

  const _OwnerOrderCard({
    required this.order,
    required this.reviewed,
    required this.highlighted,
    required this.onTap,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    final action = order.primaryAction;
    final statusStyle = _OrderStatusStyle.fromOrder(order);

    return Material(
      color: highlighted ? const Color(0xFFFFF8F0) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: highlighted
                  ? const Color(0xFFF0D4B8)
                  : const Color(0xFFE2E8E5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: highlighted
                          ? const Color(0xFFF5E6D6)
                          : const Color(0xFFD4DBD8),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.pets,
                      color: highlighted
                          ? const Color(0xFFC97C22)
                          : const Color(0xFF4D5F59),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                order.petTitle,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF122A20),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: statusStyle.bgColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                statusStyle.label,
                                style: TextStyle(
                                  color: statusStyle.color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order.subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF5A6B62),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    '￥${order.totalAmount}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF005A40),
                    ),
                  ),
                  if (order.assignedCaretakerName != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '宠托师 ${order.assignedCaretakerName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF5A6B62),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (action != null) ...[
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: action.kind == _OrderActionKind.review
                      ? onReview
                      : onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF005A40),
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(21),
                    ),
                  ),
                  child: Text(action.label),
                ),
              ] else if (order.canReview) ...[
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: onReview,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF005A40),
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(21),
                    ),
                  ),
                  child: Text(reviewed ? '查看评价' : '去评价'),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                '编号 ${order.orderId}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF9AA8A1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionText;
  final VoidCallback? onAction;

  const _StatePanel({
    required this.icon,
    required this.title,
    required this.message,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 72),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            children: [
              Icon(icon, size: 44, color: const Color(0xFF005A40)),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0B2A1F),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF5A6B62)),
              ),
              if (actionText != null && onAction != null) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF005A40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: Text(actionText!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _OrderActionKind { navigate, review }

class _OrderAction {
  final String label;
  final _OrderActionKind kind;

  const _OrderAction(this.label, this.kind);
}

class _OrderStatusStyle {
  final String label;
  final Color color;
  final Color bgColor;

  const _OrderStatusStyle({
    required this.label,
    required this.color,
    required this.bgColor,
  });

  factory _OrderStatusStyle.fromOrder(_OwnerOrder order) {
    if (order.status == 1 && order.applications.isNotEmpty) {
      return const _OrderStatusStyle(
        label: '待处理',
        color: Color(0xFFC97C22),
        bgColor: Color(0xFFFFF2DF),
      );
    }
    if (order.statusDesc.isNotEmpty) {
      final base = _OrderStatusStyle.fromStatus(order.status);
      return _OrderStatusStyle(
        label: order.statusDesc,
        color: base.color,
        bgColor: base.bgColor,
      );
    }
    return _OrderStatusStyle.fromStatus(order.status);
  }

  factory _OrderStatusStyle.fromStatus(int status) {
    return switch (status) {
      1 => const _OrderStatusStyle(
        label: '悬赏中',
        color: Color(0xFFEA865F),
        bgColor: Color(0xFFFFF3EE),
      ),
      2 => const _OrderStatusStyle(
        label: '待付款',
        color: Color(0xFF0F7A5A),
        bgColor: Color(0xFFE5F1ED),
      ),
      3 => const _OrderStatusStyle(
        label: '待履约',
        color: Color(0xFF246BCE),
        bgColor: Color(0xFFEAF1FB),
      ),
      4 => const _OrderStatusStyle(
        label: '服务中',
        color: Color(0xFF005A40),
        bgColor: Color(0xFFE5F1ED),
      ),
      5 => const _OrderStatusStyle(
        label: '待确认',
        color: Color(0xFF9C5A00),
        bgColor: Color(0xFFFFF3E3),
      ),
      6 => const _OrderStatusStyle(
        label: '已完成',
        color: Color(0xFF616161),
        bgColor: Color(0xFFEEEEEE),
      ),
      7 => const _OrderStatusStyle(
        label: '履约受阻',
        color: Color(0xFF9C5A00),
        bgColor: Color(0xFFFFF3E3),
      ),
      8 => const _OrderStatusStyle(
        label: '异常结束',
        color: Color(0xFF616161),
        bgColor: Color(0xFFF1F3F2),
      ),
      9 => const _OrderStatusStyle(
        label: '平台介入',
        color: Color(0xFFB02A37),
        bgColor: Color(0xFFFCE8EB),
      ),
      _ => const _OrderStatusStyle(
        label: '进行中',
        color: Color(0xFF5A6B62),
        bgColor: Color(0xFFF1F3F2),
      ),
    };
  }
}

class _OwnerOrder {
  final String orderId;
  final String serviceDate;
  final String totalAmount;
  final int status;
  final String statusDesc;
  final List<_OwnerOrderPet> pets;
  final List<_OwnerOrderApplication> applications;

  const _OwnerOrder({
    required this.orderId,
    required this.serviceDate,
    required this.totalAmount,
    required this.status,
    required this.statusDesc,
    required this.pets,
    required this.applications,
  });

  bool get canReview => status == 6;

  bool get needsOwnerAction {
    if (status == 7 || status == 9 || status == 2 || status == 5) {
      return true;
    }
    return status == 1 && applications.isNotEmpty;
  }

  int get actionPriority {
    if (status == 7 || status == 9) return 0;
    if (status == 2) return 1;
    if (status == 5) return 2;
    if (status == 1 && applications.isNotEmpty) return 3;
    return 99;
  }

  String get petTitle {
    if (pets.isEmpty) return '宠物服务';
    if (pets.length == 1) return pets.first.petName;
    return '${pets.first.petName} 等${pets.length}只宠物';
  }

  String get subtitle {
    final service = serviceLabel;
    final date = _formatChineseDate(serviceDate);
    return '$service · $date';
  }

  String get serviceLabel {
    if (pets.isEmpty) return '上门服务';
    final labels = pets
        .map((pet) => pet.petTypeDesc)
        .where((label) => label.isNotEmpty)
        .toSet()
        .toList();
    if (labels.isEmpty) return '上门服务';
    return labels.join('、');
  }

  String? get assignedCaretakerName {
    for (final application in applications) {
      if (application.applyStatus == 2 &&
          application.providerNickname.isNotEmpty) {
        return application.providerNickname;
      }
    }
    return null;
  }

  _OrderAction? get primaryAction {
    return switch (status) {
      2 => const _OrderAction('去支付', _OrderActionKind.navigate),
      5 => const _OrderAction('确认完成', _OrderActionKind.navigate),
      7 => const _OrderAction('处理异常', _OrderActionKind.navigate),
      9 => const _OrderAction('查看详情', _OrderActionKind.navigate),
      1 when applications.isNotEmpty =>
        const _OrderAction('去选宠托师', _OrderActionKind.navigate),
      _ => null,
    };
  }

  factory _OwnerOrder.fromJson(Map<String, dynamic> json) {
    return _OwnerOrder(
      orderId: json['orderId']?.toString() ?? '',
      serviceDate: json['serviceDate']?.toString() ?? '',
      totalAmount: json['totalAmount']?.toString() ?? '0',
      status: _asInt(json['status']),
      statusDesc: json['statusDesc']?.toString() ?? '',
      pets: _parsePets(json['pets']),
      applications: _parseApplications(json['applications']),
    );
  }

  static List<_OwnerOrderPet> _parsePets(Object? value) {
    if (value is! List) return const [];
    return value
        .map(
          (item) =>
              _OwnerOrderPet.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  static List<_OwnerOrderApplication> _parseApplications(Object? value) {
    if (value is! List) return const [];
    return value
        .map(
          (item) => _OwnerOrderApplication.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _OwnerOrderPet {
  final String petName;
  final String petTypeDesc;

  const _OwnerOrderPet({required this.petName, required this.petTypeDesc});

  factory _OwnerOrderPet.fromJson(Map<String, dynamic> json) {
    return _OwnerOrderPet(
      petName: json['petName']?.toString() ?? '',
      petTypeDesc: json['petTypeDesc']?.toString() ?? '',
    );
  }
}

class _OwnerOrderApplication {
  final String providerNickname;
  final int applyStatus;

  const _OwnerOrderApplication({
    required this.providerNickname,
    required this.applyStatus,
  });

  factory _OwnerOrderApplication.fromJson(Map<String, dynamic> json) {
    return _OwnerOrderApplication(
      providerNickname: json['providerNickname']?.toString() ?? '',
      applyStatus: _asInt(json['applyStatus']),
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

String _formatChineseDate(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '日期待定';
  final datePart = trimmed.contains('T') ? trimmed.split('T').first : trimmed;
  final parts = datePart.split('-');
  if (parts.length == 3) {
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (month != null && day != null) {
      return '$month月$day日';
    }
  }
  return datePart;
}
