import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pets/core/network/api_client.dart';

import '../data/datasources/caretaker_dashboard_remote_data_source.dart';
import '../data/repositories/caretaker_dashboard_repository_impl.dart';
import '../domain/entities/active_order.dart';
import '../domain/usecases/get_today_completed_orders_use_case.dart';
import 'caretaker_home_screen.dart';

class TodayCompletedOrdersScreen extends StatefulWidget {
  const TodayCompletedOrdersScreen({super.key});

  @override
  State<TodayCompletedOrdersScreen> createState() =>
      _TodayCompletedOrdersScreenState();
}

class _TodayCompletedOrdersScreenState extends State<TodayCompletedOrdersScreen> {
  late final GetTodayCompletedOrdersUseCase _getTodayCompletedOrdersUseCase;
  List<ActiveOrder> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final client = ApiClient();
    final dataSource = CaretakerDashboardRemoteDataSource(client);
    final repo = CaretakerDashboardRepositoryImpl(dataSource);
    _getTodayCompletedOrdersUseCase = GetTodayCompletedOrdersUseCase(repo);
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await _getTodayCompletedOrdersUseCase();
    if (!mounted) return;
    result.when(
      success: (orders) => setState(() {
        _orders = orders;
        _isLoading = false;
      }),
      failure: (error) => setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9F8),
        elevation: 0,
        title: const Text(
          '今日完成订单',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A2621),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1A2621)),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF004D36),
        onRefresh: _loadOrders,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF004D36)),
      );
    }
    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Color(0xFF8BA49A)),
                  ),
                  const SizedBox(height: 12),
                  TextButton(onPressed: _loadOrders, child: const Text('重试')),
                ],
              ),
            ),
          ),
        ],
      );
    }
    if (_orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            child: const Center(
              child: Text(
                '今天还没有已完成的订单',
                style: TextStyle(fontSize: 15, color: Color(0xFF8BA49A)),
              ),
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) => _CompletedOrderCard(order: _orders[index]),
    );
  }
}

class _CompletedOrderCard extends StatelessWidget {
  final ActiveOrder order;

  const _CompletedOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final statusLabel = order.orderStatusText.isNotEmpty
        ? order.orderStatusText
        : '已完成';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        await context.push('/caretaker/order/${order.orderId}');
        CaretakerHomeScreen.requestApplicationsRefresh();
      },
      child: Container(
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
                      Text(
                        order.petName.isEmpty ? '宠物服务' : order.petName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A2621),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order.serviceTypeText,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF004D36),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F2EF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF004D36),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 18,
                  color: Color(0xFF8BA49A),
                ),
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
                const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: Color(0xFF8BA49A),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.addressSnapshot,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF5A6B62),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
