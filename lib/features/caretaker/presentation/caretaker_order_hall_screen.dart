import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../data/datasources/order_hall_remote_data_source.dart';
import '../data/repositories/order_hall_repository_impl.dart';
import '../domain/entities/order_hall_item.dart';
import '../domain/usecases/apply_order_use_case.dart';
import '../domain/usecases/get_order_hall_use_case.dart';
import 'caretaker_applied_orders.dart';
import 'caretaker_home_screen.dart';
import 'deposit_flow_helper.dart';
import 'package:pets/core/network/api_client.dart';

class CaretakerOrderHallScreen extends StatefulWidget {
  const CaretakerOrderHallScreen({super.key});

  @override
  State<CaretakerOrderHallScreen> createState() =>
      _CaretakerOrderHallScreenState();
}

class _CaretakerOrderHallScreenState extends State<CaretakerOrderHallScreen> {
  int? _selectedPetType;
  int? _selectedServiceType;

  // 筛选条件
  double? _filterMaxDistanceKm;
  int? _filterMinAmount;
  int? _filterMaxAmount;
  String? _filterServiceDate;

  bool get _hasActiveFilter =>
      _selectedPetType != null ||
      _selectedServiceType != null ||
      _filterMaxDistanceKm != null ||
      _filterMinAmount != null ||
      _filterMaxAmount != null ||
      (_filterServiceDate != null && _filterServiceDate!.isNotEmpty);

  late final GetOrderHallUseCase _getOrderHallUseCase;
  late final ApplyOrderUseCase _applyOrderUseCase;

  List<OrderHallItem> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Track applying state per orderId to prevent double-tap
  final Set<String> _applyingOrders = {};
  // 本地乐观更新：报名成功后立即标记，待刷新后与后端 hasApplied 合并
  final Set<String> _appliedOrderIds = {};

  // 当前定位
  Position? _caretakerPosition;

  @override
  void initState() {
    super.initState();
    final client = ApiClient();
    final dataSource = OrderHallRemoteDataSource(client);
    final repo = OrderHallRepositoryImpl(dataSource);
    _getOrderHallUseCase = GetOrderHallUseCase(repo);
    _applyOrderUseCase = ApplyOrderUseCase(repo);
    _initLocationAndLoad();
  }

  Future<void> _initLocationAndLoad() async {
    // 定位与拉单并行：不等 GPS 也能先展示订单（无距离信息），定位成功后刷新补距离
    await Future.wait([_fetchLocation(), _loadOrders()]);
  }

  Future<void> _fetchLocation() async {
    // ── 1. 检查定位服务是否开启 ──────────────────────────────────────────────
    bool serviceEnabled;
    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return;
    }
    if (!serviceEnabled) {
      return;
    }

    // ── 2. 检查 / 申请权限 ──────────────────────────────────────────────────
    LocationPermission permission;
    try {
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
    } catch (_) {
      return;
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    // ── 3. 获取坐标（高精度超时 8s；超时后降级为低精度再试 8s）────────────────
    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } on TimeoutException {
      // 首次超时：降级到低精度，最多再等 8s
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        return;
      }
    } catch (_) {
      return;
    }

    if (mounted) {
      setState(() => _caretakerPosition = pos);
      // 拿到定位后重新拉一次订单，补充距离信息
      _loadOrders();
    }
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await _getOrderHallUseCase(
      caretakerLat: _caretakerPosition?.latitude,
      caretakerLng: _caretakerPosition?.longitude,
      petType: _selectedPetType,
      serviceType: _selectedServiceType,
      maxDistanceKm: _filterMaxDistanceKm,
      minAmount: _filterMinAmount,
      maxAmount: _filterMaxAmount,
      serviceDate: _filterServiceDate,
    );
    result.when(
      success: (page) => setState(() {
        _orders = page.list;
        for (final order in page.list) {
          if (order.hasApplied) {
            _appliedOrderIds.add(order.orderId);
            CaretakerAppliedOrders.instance.add(order.orderId);
          }
        }
        _isLoading = false;
      }),
      failure: (error) => setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      }),
    );
  }

  bool _hasApplied(OrderHallItem order) =>
      order.hasApplied ||
      _appliedOrderIds.contains(order.orderId) ||
      CaretakerAppliedOrders.instance.contains(order.orderId);

  void _markApplied(String orderId) {
    _appliedOrderIds.add(orderId);
    CaretakerAppliedOrders.instance.add(orderId);
  }

  Future<void> _applyOrder(String orderId) async {
    if (_applyingOrders.contains(orderId)) return;
    setState(() => _applyingOrders.add(orderId));

    final result = await _applyOrderUseCase(orderId);

    if (!mounted) return;
    setState(() => _applyingOrders.remove(orderId));

    result.when(
      success: (_) {
        setState(() => _markApplied(orderId));
        CaretakerHomeScreen.requestApplicationsRefresh();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('报名成功，等待宠物主确认'),
            backgroundColor: Color(0xFF004D36),
          ),
        );
        _loadOrders();
      },
      failure: (error) async {
        final alreadyApplied = error.message.contains('已报名');
        if (alreadyApplied) {
          setState(() => _markApplied(orderId));
          CaretakerHomeScreen.requestApplicationsRefresh();
          _loadOrders();
        } else if (isDepositRelatedError(error)) {
          await showDepositRequiredDialog(context, message: error.message);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(alreadyApplied ? '您已报名该订单' : error.message),
            backgroundColor:
                alreadyApplied ? const Color(0xFF004D36) : Colors.red,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      body: SafeArea(
        child: Column(
          children: [
            _buildCustomHeader(),
            Expanded(child: _buildListView()),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: _openFilterSheet,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.menu, color: Color(0xFF1A2621), size: 28),
                if (_hasActiveFilter)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF004D36),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '接单大厅',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A2621),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF004D36)));
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loadOrders,
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF004D36)),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (_orders.isEmpty) {
      return const Center(
        child: Text('暂无可接订单', style: TextStyle(color: Colors.grey)),
      );
    }
    return RefreshIndicator(
      color: const Color(0xFF004D36),
      onRefresh: _loadOrders,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final order = _orders[index];
          return _OrderCard(
            order: order,
            hasApplied: _hasApplied(order),
            isApplying: _applyingOrders.contains(order.orderId),
            onApply: () => _applyOrder(order.orderId),
          );
        },
      ),
    );
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<_FilterResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _FilterSheet(
        initialPetType: _selectedPetType,
        initialServiceType: _selectedServiceType,
        initialMaxDistanceKm: _filterMaxDistanceKm,
        initialMinAmount: _filterMinAmount,
        initialMaxAmount: _filterMaxAmount,
        initialServiceDate: _filterServiceDate,
      ),
    );
    if (result == null) return;
    setState(() {
      _selectedPetType = result.petType;
      _selectedServiceType = result.serviceType;
      _filterMaxDistanceKm = result.maxDistanceKm;
      _filterMinAmount = result.minAmount;
      _filterMaxAmount = result.maxAmount;
      _filterServiceDate = result.serviceDate;
    });
    _loadOrders();
  }
}

class _OrderCard extends StatelessWidget {
  final OrderHallItem order;
  final bool hasApplied;
  final bool isApplying;
  final VoidCallback onApply;

  const _OrderCard({
    required this.order,
    required this.hasApplied,
    required this.isApplying,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final hasAvatar = order.ownerAvatarUrl != null && order.ownerAvatarUrl!.isNotEmpty;
    final initials = order.ownerNickname.isNotEmpty
        ? order.ownerNickname.characters.first
        : '?';

    final filterDescs = order.hardFilterTagDescs;
    final filterText = filterDescs.isEmpty ? '无特殊要求' : filterDescs.join('、');
    final filterColor = filterDescs.isEmpty
        ? const Color(0xFF8BA49A)
        : const Color(0xFFD97706);

    return GestureDetector(
      onTap: () => context.push(
        '/caretaker/order/${order.orderId}',
        extra: hasApplied,
      ),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEBEBEB)),
              boxShadow: const [
                BoxShadow(color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 4))
              ],
            ),
            child: Column(
              children: [
                // ── 顶行：头像 | 服务类型+地区 | 价格 ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 宠物主头像
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F2EF),
                        shape: BoxShape.circle,
                        image: hasAvatar
                            ? DecorationImage(
                                image: NetworkImage(order.ownerAvatarUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: hasAvatar
                          ? null
                          : Center(
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF004D36),
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (order.serviceTypeSummary.isNotEmpty) ...[
                            Text(
                              order.serviceTypeSummary,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF004D36),
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          // 地区·距离
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 14, color: Color(0xFF5A6B62)),
                              const SizedBox(width: 4),
                              Text(
                                '${order.addressDistrict} · 距 ${order.distanceKm.toStringAsFixed(1)}km',
                                style: const TextStyle(
                                    fontSize: 13, color: Color(0xFF5A6B62)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 价格
                    Text(
                      '¥${order.totalAmount}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF003827),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // ── 中间两格：服务时段 | 门槛要求 ──
                Row(
                  children: [
                    // 服务时段（日期+时间两行）
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F9F8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.access_time,
                                    size: 13, color: Color(0xFF5A6B62)),
                                SizedBox(width: 4),
                                Text('服务时段',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF5A6B62))),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              order.serviceDate,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A2621),
                              ),
                            ),
                            if (order.serviceTimeSlot.isNotEmpty)
                              Text(
                                order.serviceTimeSlot,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF5A6B62),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 硬性门槛
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F9F8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.tune_rounded,
                                    size: 13, color: Color(0xFF5A6B62)),
                                SizedBox(width: 4),
                                Text('门槛要求',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF5A6B62))),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              filterText,
                              style: TextStyle(
                                fontSize: filterDescs.isEmpty ? 13 : 14,
                                fontWeight: filterDescs.isEmpty
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                                color: filterColor,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // ── 底行：申请人数 | 报名按钮 ──
                Row(
                  children: [
                    const Icon(Icons.people_outline,
                        size: 16, color: Color(0xFF8BA49A)),
                    const SizedBox(width: 4),
                    Text(
                      '${order.applicationCount} 人已申请',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF5A6B62)),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: hasApplied || isApplying ? null : onApply,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF004D36),
                        disabledBackgroundColor: const Color(0xFFE8F2EF),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                      child: isApplying
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              hasApplied ? '已报名' : '立即报名',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: hasApplied
                                    ? const Color(0xFF8BA49A)
                                    : Colors.white,
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (order.isHot)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFFF06A42),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: const Text(
                  '热门',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 筛选弹窗数据 & Widget
// ─────────────────────────────────────────────────────────────────────────────

class _FilterResult {
  final int? petType;
  final int? serviceType;
  final double? maxDistanceKm;
  final int? minAmount;
  final int? maxAmount;
  final String? serviceDate;

  const _FilterResult({
    this.petType,
    this.serviceType,
    this.maxDistanceKm,
    this.minAmount,
    this.maxAmount,
    this.serviceDate,
  });
}

class _FilterSheet extends StatefulWidget {
  final int? initialPetType;
  final int? initialServiceType;
  final double? initialMaxDistanceKm;
  final int? initialMinAmount;
  final int? initialMaxAmount;
  final String? initialServiceDate;

  const _FilterSheet({
    this.initialPetType,
    this.initialServiceType,
    this.initialMaxDistanceKm,
    this.initialMinAmount,
    this.initialMaxAmount,
    this.initialServiceDate,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  static const _petOptions = <String, int?>{
    '全部宠物': null,
    '猫': 1,
    '狗': 2,
    '异宠': 3,
  };
  static const _actionOptions = <String, int?>{
    '全部操作': null,
    '喂': 1,
    '遛': 2,
  };
  static const _distanceOptions = <double>[0, 1, 3, 5, 10];
  int? _selectedPetType;
  int? _selectedServiceType;
  late double _selectedDistance;

  final TextEditingController _minAmountCtrl = TextEditingController();
  final TextEditingController _maxAmountCtrl = TextEditingController();

  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedPetType = widget.initialPetType;
    _selectedServiceType = widget.initialServiceType;
    _selectedDistance = widget.initialMaxDistanceKm ?? 0;
    _minAmountCtrl.text = widget.initialMinAmount?.toString() ?? '';
    _maxAmountCtrl.text = widget.initialMaxAmount?.toString() ?? '';
    if (widget.initialServiceDate != null &&
        widget.initialServiceDate!.isNotEmpty) {
      _selectedDate = DateTime.tryParse(widget.initialServiceDate!);
    }
  }

  @override
  void dispose() {
    _minAmountCtrl.dispose();
    _maxAmountCtrl.dispose();
    super.dispose();
  }

  String _distanceLabel(double d) => d == 0 ? '不限' : '${d.toInt()} km';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF004D36),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _reset() => setState(() {
        _selectedPetType = null;
        _selectedServiceType = null;
        _selectedDistance = 0;
        _minAmountCtrl.clear();
        _maxAmountCtrl.clear();
        _selectedDate = null;
      });

  void _apply() {
    final minAmount = int.tryParse(_minAmountCtrl.text.trim());
    final maxAmount = int.tryParse(_maxAmountCtrl.text.trim());
    final d = _selectedDate;
    final dateStr = d != null
        ? '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'
        : null;
    Navigator.pop(
      context,
      _FilterResult(
        petType: _selectedPetType,
        serviceType: _selectedServiceType,
        maxDistanceKm: _selectedDistance > 0 ? _selectedDistance : null,
        minAmount: minAmount,
        maxAmount: maxAmount,
        serviceDate: dateStr,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFDDE5E2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('筛选条件',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A2621))),
                TextButton(
                  onPressed: _reset,
                  child: const Text('重置',
                      style: TextStyle(color: Color(0xFF5A6B62))),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOptionGroup(
                  title: '宠物',
                  options: _petOptions,
                  selectedValue: _selectedPetType,
                  onSelect: (value) =>
                      setState(() => _selectedPetType = value),
                ),
                const SizedBox(height: 20),
                _buildOptionGroup(
                  title: '操作',
                  options: _actionOptions,
                  selectedValue: _selectedServiceType,
                  onSelect: (value) =>
                      setState(() => _selectedServiceType = value),
                ),
                const SizedBox(height: 20),
                const Text('距离范围',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A2621))),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: _distanceOptions.map((d) {
                    final selected = _selectedDistance == d;
                    return ChoiceChip(
                      label: Text(_distanceLabel(d)),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _selectedDistance = d),
                      selectedColor: const Color(0xFF004D36),
                      labelStyle: TextStyle(
                          color: selected
                              ? Colors.white
                              : const Color(0xFF5A6B62),
                          fontSize: 13),
                      backgroundColor: const Color(0xFFE8F2EF),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                const Text('价格区间',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A2621))),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: _AmountField(
                            controller: _minAmountCtrl, hint: '最低价')),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('—',
                          style: TextStyle(color: Color(0xFF8BA49A))),
                    ),
                    Expanded(
                        child: _AmountField(
                            controller: _maxAmountCtrl, hint: '最高价')),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('服务日期',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A2621))),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedDate != null
                            ? const Color(0xFF004D36)
                            : const Color(0xFFDDE5E2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 16,
                            color: _selectedDate != null
                                ? const Color(0xFF004D36)
                                : const Color(0xFF8BA49A)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedDate != null
                                ? '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'
                                : '不限日期',
                            style: TextStyle(
                              color: _selectedDate != null
                                  ? const Color(0xFF1A2621)
                                  : const Color(0xFF8BA49A),
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (_selectedDate != null)
                          GestureDetector(
                            onTap: () =>
                                setState(() => _selectedDate = null),
                            child: const Icon(Icons.close,
                                size: 16, color: Color(0xFF8BA49A)),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _apply,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF004D36),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                ),
                child: const Text('确定',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionGroup({
    required String title,
    required Map<String, int?> options,
    required int? selectedValue,
    required ValueChanged<int?> onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A2621))),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.entries.map((entry) {
            final selected = selectedValue == entry.value;
            return ChoiceChip(
              label: Text(entry.key),
              selected: selected,
              onSelected: (_) => onSelect(entry.value),
              selectedColor: const Color(0xFF004D36),
              backgroundColor: const Color(0xFFE8F2EF),
              labelStyle: TextStyle(
                color: selected ? Colors.white : const Color(0xFF5A6B62),
                fontSize: 13,
              ),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const _AmountField({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFDDE5E2)),
    );
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        hintText: hint,
        prefixText: '¥ ',
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF004D36)),
        ),
      ),
    );
  }
}
