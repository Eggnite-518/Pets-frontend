import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pets/core/auth/auth_token_store.dart';
import 'package:pets/core/network/api_client.dart';

import '../data/datasources/caretaker_dashboard_remote_data_source.dart';
import '../data/datasources/caretaker_training_remote_data_source.dart';
import '../data/datasources/order_hall_remote_data_source.dart';
import '../data/repositories/caretaker_dashboard_repository_impl.dart';
import '../data/repositories/order_hall_repository_impl.dart';
import '../domain/entities/active_order.dart';
import '../domain/entities/caretaker_stats.dart';
import '../domain/entities/my_application.dart';
import '../domain/usecases/cancel_application_use_case.dart';
import '../domain/usecases/get_active_orders_use_case.dart';
import '../domain/usecases/get_caretaker_stats_use_case.dart';
import '../domain/usecases/get_my_applications_use_case.dart';
import '../domain/usecases/get_pending_confirmation_orders_use_case.dart';
import '../domain/usecases/get_today_completed_orders_use_case.dart';

class CaretakerHomeScreen extends StatefulWidget {
  const CaretakerHomeScreen({super.key});

  /// 从接单大厅/详情页报名或履约状态变化后，刷新首页列表
  static void requestApplicationsRefresh() {
    _CaretakerHomeScreenState.refreshCallback?.call();
  }

  @override
  State<CaretakerHomeScreen> createState() => _CaretakerHomeScreenState();
}

class _CaretakerHomeScreenState extends State<CaretakerHomeScreen> {
  static VoidCallback? refreshCallback;
  late final GetCaretakerStatsUseCase _getStatsUseCase;
  late final GetActiveOrdersUseCase _getActiveOrdersUseCase;
  late final GetPendingConfirmationOrdersUseCase _getPendingConfirmationOrdersUseCase;
  late final GetTodayCompletedOrdersUseCase _getTodayCompletedOrdersUseCase;
  late final GetMyApplicationsUseCase _getMyApplicationsUseCase;
  late final CancelApplicationUseCase _cancelApplicationUseCase;
  late final CaretakerTrainingRemoteDataSource _trainingDs;

  CaretakerStats? _stats;
  List<ActiveOrder> _activeOrders = [];
  List<ActiveOrder> _pendingConfirmationOrders = [];
  List<ActiveOrder> _todayCompletedOrders = [];
  List<MyApplication> _applications = [];
  TrainingStatus? _trainingStatus;
  bool _isLoading = true;
  // 记录哪些数据块加载失败，供顶部 banner 展示
  final Set<String> _failedBlocks = {};
  // 是否因权限不足导致失败（需要重新登录）
  bool _isAuthError = false;
  // 实际错误信息（调试用）
  String? _lastErrorMsg;

  @override
  void initState() {
    super.initState();
    final client = ApiClient();
    final dashboardDataSource = CaretakerDashboardRemoteDataSource(client);
    final dashboardRepo = CaretakerDashboardRepositoryImpl(dashboardDataSource);
    _getStatsUseCase = GetCaretakerStatsUseCase(dashboardRepo);
    _getActiveOrdersUseCase = GetActiveOrdersUseCase(dashboardRepo);
    _getPendingConfirmationOrdersUseCase =
        GetPendingConfirmationOrdersUseCase(dashboardRepo);
    _getTodayCompletedOrdersUseCase =
        GetTodayCompletedOrdersUseCase(dashboardRepo);
    _getMyApplicationsUseCase = GetMyApplicationsUseCase(dashboardRepo);

    final orderHallDataSource = OrderHallRemoteDataSource(client);
    final orderHallRepo = OrderHallRepositoryImpl(orderHallDataSource);
    _cancelApplicationUseCase = CancelApplicationUseCase(orderHallRepo);
    _trainingDs = CaretakerTrainingRemoteDataSource(client);

    refreshCallback = _refreshHomeData;
    _loadAll();
  }

  @override
  void dispose() {
    if (refreshCallback == _refreshHomeData) {
      refreshCallback = null;
    }
    super.dispose();
  }

  Future<void> _refreshHomeData() async {
    if (!mounted) return;
    await _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _failedBlocks.clear();
      _isAuthError = false;
    });

    final results = await Future.wait([
      _getStatsUseCase(),
      _getActiveOrdersUseCase(),
      _getPendingConfirmationOrdersUseCase(),
      _getTodayCompletedOrdersUseCase(),
      _getMyApplicationsUseCase(),
      _trainingDs.getStatus(),
    ]);

    if (!mounted) return;
    setState(() {
      bool authError = false;
      String? firstErrMsg;

      results[0].when(
        success: (data) => _stats = data as CaretakerStats,
        failure: (e) {
          _failedBlocks.add('统计数据');
          firstErrMsg ??= '[${e.statusCode ?? "?"}] ${e.message}';
          if (e.statusCode == 401 || e.statusCode == 403) authError = true;
        },
      );
      results[1].when(
        success: (data) => _activeOrders = data as List<ActiveOrder>,
        failure: (e) {
          _failedBlocks.add('履约订单');
          firstErrMsg ??= '[${e.statusCode ?? "?"}] ${e.message}';
          if (e.statusCode == 401 || e.statusCode == 403) authError = true;
        },
      );
      results[2].when(
        success: (data) => _pendingConfirmationOrders = data as List<ActiveOrder>,
        failure: (e) {
          _failedBlocks.add('等待确认');
          firstErrMsg ??= '[${e.statusCode ?? "?"}] ${e.message}';
          if (e.statusCode == 401 || e.statusCode == 403) authError = true;
        },
      );
      results[3].when(
        success: (data) => _todayCompletedOrders = data as List<ActiveOrder>,
        failure: (e) {
          _failedBlocks.add('今日完成');
          firstErrMsg ??= '[${e.statusCode ?? "?"}] ${e.message}';
          if (e.statusCode == 401 || e.statusCode == 403) authError = true;
        },
      );
      results[4].when(
        success: (data) => _applications = data as List<MyApplication>,
        failure: (e) {
          _failedBlocks.add('报名记录');
          firstErrMsg ??= '[${e.statusCode ?? "?"}] ${e.message}';
          if (e.statusCode == 401 || e.statusCode == 403) authError = true;
        },
      );
      results[5].when(
        success: (data) => _trainingStatus = data as TrainingStatus,
        failure: (_) {},
      );

      _isAuthError = authError;
      _lastErrorMsg = firstErrMsg;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF004D36),
          onRefresh: _loadAll,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _CaretakerAppBar(),
                if (_failedBlocks.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  if (_isAuthError)
                    _AuthErrorBanner(
                      onRelogin: () async {
                        await AuthTokenStore.instance.clearAll();
                        if (context.mounted) context.go('/login');
                      },
                    )
                  else
                    _ErrorBanner(
                      message: _lastErrorMsg != null
                          ? '${_failedBlocks.join('、')}加载失败：$_lastErrorMsg'
                          : '${_failedBlocks.join('、')}加载失败，下拉刷新重试',
                    ),
                ],
                const SizedBox(height: 20),
                _buildStatCards(),
                const SizedBox(height: 16),
                _TrainingEntryCard(status: _trainingStatus),
                const SizedBox(height: 16),
                _buildSectionCard(child: _buildActiveOrdersSection()),
                if (_pendingConfirmationOrders.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildSectionCard(child: _buildPendingConfirmationSection()),
                ],
                const SizedBox(height: 12),
                _buildSectionCard(child: _buildApplicationsSection()),
                const SizedBox(height: 12),
                _buildSectionCard(child: _buildTodayCompletedSection()),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _buildStatCards() {
    if (_isLoading) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.calendar_today_outlined,
                  value: '--',
                  title: '今日待服务',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.task_alt_outlined,
                  value: '--',
                  title: '今日完成',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.verified_user_outlined,
                  value: '--',
                  title: '信用分',
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      );
    }
    final pendingCount = _stats?.pendingPaymentCount ?? 0;
    final completedCount = _todayCompletedOrders.length;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.calendar_today_outlined,
                value: '${_stats?.todayOrderCount ?? 0}',
                title: '今日待服务',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TappableStatCard(
                icon: Icons.task_alt_outlined,
                value: _isLoading ? '--' : '$completedCount',
                title: '今日完成',
                onTap: () => context.push('/caretaker/today-completed'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.verified_user_outlined,
                value: _stats == null || _stats!.creditScore == 0
                    ? '--'
                    : '${_stats!.creditScore}',
                title: '信用分',
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox()),
          ],
        ),
        if (pendingCount > 0) ...[
          const SizedBox(height: 12),
          _PendingPaymentBanner(count: pendingCount),
        ],
      ],
    );
  }

  Widget _buildTodayCompletedSection() {
    const int previewCount = 3;
    final previewOrders = _todayCompletedOrders.length > previewCount
        ? _todayCompletedOrders.sublist(0, previewCount)
        : _todayCompletedOrders;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  '今日完成',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A2621),
                  ),
                ),
                if (!_isLoading && _todayCompletedOrders.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F2EF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_todayCompletedOrders.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF004D36),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            InkWell(
              onTap: () => context.push('/caretaker/today-completed'),
              child: const Text(
                '查看全部',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF004D36),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          '服务日期为今天且已结算完成的订单',
          style: TextStyle(fontSize: 13, color: Color(0xFF8BA49A)),
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(color: Color(0xFF004D36)),
          )
        else if (_todayCompletedOrders.isEmpty)
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push('/caretaker/today-completed'),
            child: const _EmptyCard(message: '今天还没有已完成的订单，点此查看历史'),
          )
        else ...[
          ...previewOrders.map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _FulfillingOrderCard(
                order: order,
                onReturnFromDetail: _refreshHomeData,
              ),
            ),
          ),
          if (_todayCompletedOrders.length > previewCount)
            TextButton(
              onPressed: () => context.push('/caretaker/today-completed'),
              child: Text(
                '还有 ${_todayCompletedOrders.length - previewCount} 单，查看全部',
                style: const TextStyle(color: Color(0xFF004D36)),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildActiveOrdersSection() {
    const int previewCount = 3;
    final previewOrders = _activeOrders.length > previewCount
        ? _activeOrders.sublist(0, previewCount)
        : _activeOrders;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '正在履约中',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A2621)),
            ),
            InkWell(
              onTap: () => context.push('/caretaker/active-orders'),
              child: const Text('查看全部',
                  style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF004D36),
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          const Center(child: CircularProgressIndicator(color: Color(0xFF004D36)))
        else if (_activeOrders.isEmpty)
          const _EmptyCard(message: '暂无履约中订单')
        else ...[
          ...previewOrders.map((order) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _FulfillingOrderCard(
                  order: order,
                  onReturnFromDetail: _refreshHomeData,
                ),
              )),
          if (_activeOrders.length > previewCount)
            TextButton(
              onPressed: () => context.push('/caretaker/active-orders'),
              child: Text('还有 ${_activeOrders.length - previewCount} 条，查看全部',
                  style: const TextStyle(color: Color(0xFF004D36))),
            ),
        ],
      ],
    );
  }

  Widget _buildPendingConfirmationSection() {
    const int previewCount = 3;
    final previewOrders = _pendingConfirmationOrders.length > previewCount
        ? _pendingConfirmationOrders.sublist(0, previewCount)
        : _pendingConfirmationOrders;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '等待确认',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A2621),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_pendingConfirmationOrders.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF9C5A00),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          '打卡已完成，等待宠主确认后结算',
          style: TextStyle(fontSize: 13, color: Color(0xFF8BA49A)),
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          const Center(child: CircularProgressIndicator(color: Color(0xFF004D36)))
        else ...[
          ...previewOrders.map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _FulfillingOrderCard(
                order: order,
                onReturnFromDetail: _refreshHomeData,
              ),
            ),
          ),
          if (_pendingConfirmationOrders.length > previewCount)
            Text(
              '还有 ${_pendingConfirmationOrders.length - previewCount} 条等待确认',
              style: const TextStyle(fontSize: 13, color: Color(0xFF8BA49A)),
            ),
        ],
      ],
    );
  }

  Widget _buildApplicationsSection() {
    const int previewCount = 3;
    final previewApps = _applications.length > previewCount
        ? _applications.sublist(0, previewCount)
        : _applications;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('正在报名中',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A2621))),
            InkWell(
              onTap: () => context.push('/caretaker/applications'),
              child: const Text('查看全部',
                  style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF004D36),
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          const Center(child: CircularProgressIndicator(color: Color(0xFF004D36)))
        else if (_applications.isEmpty)
          const _EmptyCard(message: '暂无报名中订单')
        else ...[
          ...previewApps.map((app) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ApplyingOrderCard(
                  application: app,
                  cancelUseCase: _cancelApplicationUseCase,
                  onOpen: () => context.push('/caretaker/order/${app.orderId}', extra: true),
                  onCancelled: () => setState(() => _applications.remove(app)),
                ),
              )),
          if (_applications.length > previewCount)
            TextButton(
              onPressed: () => context.push('/caretaker/applications'),
              child: Text('还有 ${_applications.length - previewCount} 条，查看全部',
                  style: const TextStyle(color: Color(0xFF004D36))),
            ),
        ],
      ],
    );
  }
}

class _CaretakerAppBar extends StatelessWidget {
  const _CaretakerAppBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.location_on_outlined, color: Color(0xFF5A6662)),
        const SizedBox(width: 4),
        const Text('北京',
            style: TextStyle(fontSize: 16.5, color: Color(0xFF5A6662))),
        const Spacer(),
        const Text('宠托师',
            style: TextStyle(
                fontSize: 18,
                color: Color(0xFF02241A),
                fontWeight: FontWeight.w800)),
        const Spacer(),
        GestureDetector(
          onTap: () => context.go('/caretaker/profile'),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey[300],
            child: const Icon(
              Icons.person,
              size: 20,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String title;

  const _StatCard({required this.icon, required this.value, required this.title});

  @override
  Widget build(BuildContext context) {
    return _StatCardBody(icon: icon, value: value, title: title);
  }
}

class _TappableStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String title;
  final VoidCallback onTap;

  const _TappableStatCard({
    required this.icon,
    required this.value,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: _StatCardBody(icon: icon, value: value, title: title),
      ),
    );
  }
}

class _StatCardBody extends StatelessWidget {
  final IconData icon;
  final String value;
  final String title;

  const _StatCardBody({
    required this.icon,
    required this.value,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEBEBEB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xFF5A6B62), size: 24),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF003827),
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 13, color: Color(0xFF5A6B62)),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEBEBEB)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, color: Color(0xFF8BA49A)),
      ),
    );
  }
}

class _FulfillingOrderCard extends StatelessWidget {
  final ActiveOrder order;
  final VoidCallback? onReturnFromDetail;

  const _FulfillingOrderCard({
    required this.order,
    this.onReturnFromDetail,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        await context.push('/caretaker/order/${order.orderId}');
        onReturnFromDetail?.call();
      },
      child: _buildCard(context),
    );
  }

  Widget _buildCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEBEBEB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFE8F2EF),
                backgroundImage: order.petAvatarUrl.isNotEmpty
                    ? NetworkImage(order.petAvatarUrl)
                    : null,
                child: order.petAvatarUrl.isEmpty
                    ? const Icon(Icons.pets, color: Color(0xFF004D36))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.petName,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A2621))),
                    const SizedBox(height: 4),
                    Text(order.serviceTypeText,
                        style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF004D36),
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              _OrderStatusBadge(orderStatus: order.orderStatus, statusText: order.orderStatusText),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.access_time, size: 18, color: Color(0xFF8BA49A)),
              const SizedBox(width: 8),
              Text(
                '${order.serviceTimeSlot} (${order.serviceDate})',
                style: const TextStyle(fontSize: 14, color: Color(0xFF5A6B62)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 18, color: Color(0xFF8BA49A)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(order.addressSnapshot,
                    style: const TextStyle(
                        fontSize: 14, color: Color(0xFF5A6B62))),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ApplyingOrderCard extends StatefulWidget {
  final MyApplication application;
  final CancelApplicationUseCase cancelUseCase;
  final VoidCallback onOpen;
  final VoidCallback onCancelled;

  const _ApplyingOrderCard({
    required this.application,
    required this.cancelUseCase,
    required this.onOpen,
    required this.onCancelled,
  });

  @override
  State<_ApplyingOrderCard> createState() => _ApplyingOrderCardState();
}

class _ApplyingOrderCardState extends State<_ApplyingOrderCard> {
  bool _isCancelling = false;

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认取消报名？'),
        content: const Text('取消后该报名记录将删除，可重新报名。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('再想想')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确认取消',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isCancelling = true);
    final result =
        await widget.cancelUseCase(widget.application.orderId);
    if (!mounted) return;
    setState(() => _isCancelling = false);

    result.when(
      success: (_) => widget.onCancelled(),
      failure: (error) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.red),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: widget.onOpen,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEBEBEB)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFFE8F2EF),
              backgroundImage: widget.application.petAvatarUrl.isNotEmpty
                  ? NetworkImage(widget.application.petAvatarUrl)
                  : null,
              child: widget.application.petAvatarUrl.isEmpty
                  ? const Icon(Icons.pets, color: Color(0xFF004D36))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.application.petName,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A2621))),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildTag('${widget.application.distanceKm}km'),
                      const SizedBox(width: 8),
                      _buildTag(widget.application.serviceTypeText),
                    ],
                  ),
                  if (widget.application.serviceTimeSlot.isNotEmpty ||
                      widget.application.serviceDate.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      [
                        if (widget.application.serviceTimeSlot.isNotEmpty)
                          widget.application.serviceTimeSlot,
                        if (widget.application.serviceDate.isNotEmpty)
                          widget.application.serviceDate,
                      ].join(' · '),
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF5A6B62)),
                    ),
                  ],
                  if (widget.application.addressSnapshot.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.application.addressSnapshot,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF8BA49A)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('¥${widget.application.totalAmount}',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF003827))),
                const SizedBox(height: 4),
                Text(
                  widget.application.orderStatusText.isNotEmpty
                      ? widget.application.orderStatusText
                      : '等待反馈',
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8BA49A),
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                _isCancelling
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFFB0B0B0)),
                      )
                    : GestureDetector(
                        onTap: _cancel,
                        child: const Text('取消报名',
                            style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFB0B0B0),
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xFFB0B0B0))),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: const Color(0xFFE8F2EF),
          borderRadius: BorderRadius.circular(10)),
      child: Text(text,
          style: const TextStyle(color: Color(0xFF5A6B62), fontSize: 11)),
    );
  }
}

class _PendingPaymentBanner extends StatelessWidget {
  final int count;
  const _PendingPaymentBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD966).withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFFB8860B)),
          const SizedBox(width: 8),
          Text(
            '有 $count 单等待宠主付款',
            style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF7A5800),
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB3B3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: Color(0xFFD32F2F)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFB71C1C),
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthErrorBanner extends StatelessWidget {
  final VoidCallback onRelogin;
  const _AuthErrorBanner({required this.onRelogin});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD54F)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded,
              size: 16, color: Color(0xFFF57F17)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '宠托师权限未激活，请重新登录以同步身份',
              style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF7A5800),
                  fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRelogin,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF57F17),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '重新登录',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 培训入口卡片 ──────────────────────────────────────────────────────────────

class _TrainingEntryCard extends StatelessWidget {
  final TrainingStatus? status;

  const _TrainingEntryCard({this.status});

  @override
  Widget build(BuildContext context) {
    // 未加载到时也显示，但内容稍简单
    final s = status;
    final bool isPassed = s?.isPassed ?? false;
    final bool canExam = s?.canStartExam ?? false;

    Color bg;
    Color iconBg;
    Color iconColor;
    IconData icon;
    String title;
    String subtitle;
    String btnLabel;

    if (isPassed) {
      bg = const Color(0xFFE8F2EF);
      iconBg = const Color(0xFF004D36);
      iconColor = Colors.white;
      icon = Icons.verified_rounded;
      title = '平台培训认证';
      subtitle = '认证已通过，可以正式接单';
      btnLabel = '查看详情';
    } else if (canExam) {
      bg = const Color(0xFFFFF3DC);
      iconBg = const Color(0xFFE9820A);
      iconColor = Colors.white;
      icon = Icons.assignment_outlined;
      title = '平台培训认证';
      subtitle = '学习已完成，去参加资格考试';
      btnLabel = '去考试';
    } else if (s?.verifyStatus == 1) {
      bg = const Color(0xFFFFF8ED);
      iconBg = const Color(0xFFE9820A);
      iconColor = Colors.white;
      icon = Icons.menu_book_outlined;
      title = '平台培训认证';
      subtitle = '培训进行中，继续完成学习';
      btnLabel = '继续学习';
    } else {
      bg = const Color(0xFFF0F5F3);
      iconBg = const Color(0xFF5A6B62);
      iconColor = Colors.white;
      icon = Icons.school_outlined;
      title = '平台培训认证';
      subtitle = '完成认证后才能在接单大厅接单';
      btnLabel = '去认证';
    }

    return GestureDetector(
      onTap: () => context.push('/caretaker/training'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration:
                  BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A2621)),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF5A6B62)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isPassed
                    ? const Color(0xFF004D36)
                    : const Color(0xFF1A2621),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                btnLabel,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderStatusBadge extends StatelessWidget {
  final int orderStatus;
  final String statusText;
  const _OrderStatusBadge({required this.orderStatus, required this.statusText});

  String _fallbackLabel(int status) {
    switch (status) {
      case 3: return '待上门';
      case 4: return '履约中';
      case 5: return '待宠主确认';
      case 6: return '已完成';
      case 7: return '履约受阻';
      case 8: return '异常结束';
      case 9: return '平台介入';
      default: return '进行中';
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = statusText.isNotEmpty ? statusText : _fallbackLabel(orderStatus);
    final background = switch (orderStatus) {
      4 => const Color(0xFF004D36),
      5 => const Color(0xFFFFF3E3),
      7 => const Color(0xFFFFF3E3),
      8 => const Color(0xFFF1F3F2),
      9 => const Color(0xFFFCE8EB),
      _ => const Color(0xFFE8F2EF),
    };
    final foreground = switch (orderStatus) {
      4 => Colors.white,
      5 => const Color(0xFF9C5A00),
      7 => const Color(0xFF9C5A00),
      8 => const Color(0xFF5A6B62),
      9 => const Color(0xFFB02A37),
      _ => const Color(0xFF004D36),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
