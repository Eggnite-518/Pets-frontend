import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pets/core/network/api_client.dart';

import '../data/datasources/caretaker_dashboard_remote_data_source.dart';
import '../data/datasources/order_hall_remote_data_source.dart';
import '../data/repositories/caretaker_dashboard_repository_impl.dart';
import '../data/repositories/order_hall_repository_impl.dart';
import '../domain/entities/my_application.dart';
import '../domain/usecases/cancel_application_use_case.dart';
import '../domain/usecases/get_my_applications_use_case.dart';

class AllApplicationsScreen extends StatefulWidget {
  const AllApplicationsScreen({super.key});

  @override
  State<AllApplicationsScreen> createState() => _AllApplicationsScreenState();
}

class _AllApplicationsScreenState extends State<AllApplicationsScreen> {
  late final GetMyApplicationsUseCase _getMyApplicationsUseCase;
  late final CancelApplicationUseCase _cancelApplicationUseCase;
  List<MyApplication> _applications = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final client = ApiClient();
    final dashboardDataSource = CaretakerDashboardRemoteDataSource(client);
    final dashboardRepo = CaretakerDashboardRepositoryImpl(dashboardDataSource);
    _getMyApplicationsUseCase = GetMyApplicationsUseCase(dashboardRepo);

    final orderHallDataSource = OrderHallRemoteDataSource(client);
    final orderHallRepo = OrderHallRepositoryImpl(orderHallDataSource);
    _cancelApplicationUseCase = CancelApplicationUseCase(orderHallRepo);

    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await _getMyApplicationsUseCase();
    if (!mounted) return;
    result.when(
      success: (apps) => setState(() {
        _applications = apps;
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
        title: const Text('正在报名中',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A2621))),
        iconTheme: const IconThemeData(color: Color(0xFF1A2621)),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF004D36),
        onRefresh: _loadApplications,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF004D36)));
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!,
                style: const TextStyle(color: Color(0xFF8BA49A))),
            const SizedBox(height: 12),
            TextButton(onPressed: _loadApplications, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_applications.isEmpty) {
      return const Center(
        child: Text('暂无报名中订单',
            style: TextStyle(fontSize: 15, color: Color(0xFF8BA49A))),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _applications.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) => _ApplicationCard(
        application: _applications[index],
        cancelUseCase: _cancelApplicationUseCase,
        onCancelled: () => setState(() => _applications.removeAt(index)),
      ),
    );
  }
}

class _ApplicationCard extends StatefulWidget {
  final MyApplication application;
  final CancelApplicationUseCase cancelUseCase;
  final VoidCallback onCancelled;

  const _ApplicationCard({
    required this.application,
    required this.cancelUseCase,
    required this.onCancelled,
  });

  @override
  State<_ApplicationCard> createState() => _ApplicationCardState();
}

class _ApplicationCardState extends State<_ApplicationCard> {
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
    final result = await widget.cancelUseCase(widget.application.orderId);
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
      onTap: () => context.push('/caretaker/order/${widget.application.orderId}', extra: true),
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
