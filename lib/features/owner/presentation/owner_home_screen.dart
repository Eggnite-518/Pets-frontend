import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pets/core/network/api_client.dart';
import 'package:pets/core/network/api_exception.dart';

/// 1. 宠主端首页 (主页面，仅做组件拼装)
class OwnerHomeScreen extends StatelessWidget {
  const OwnerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F5),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF005A40),
        shape: const CircleBorder(),
        elevation: 4,
        onPressed: () => context.push('/order/create'),
        child: const Icon(Icons.add, color: Colors.white, size: 36),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: const [
            _HomeAppBar(), // 顶部导航区
            SizedBox(height: 16),
            _HeroBanner(), // 绿色品牌卡片
            SizedBox(height: 16),
            _ServiceGrid(), // 上门喂养/遛狗入口
            SizedBox(height: 18),
            _OrderSection(), // 订单列表
          ],
        ),
      ),
    );
  }
}

/// ================= 拆分出的子组件 =================

/// 2. 顶部导航区 (定位、标题、身份切换)
class _HomeAppBar extends StatelessWidget {
  const _HomeAppBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.location_on_outlined, color: Color(0xFF5A6662)),
        const SizedBox(width: 4),
        const Text(
          '上海',
          style: TextStyle(fontSize: 16.5, color: Color(0xFF5A6662)),
        ),
        const Spacer(),
        const Text(
          '宠托',
          style: TextStyle(
            fontSize: 18,
            color: Color(0xFF02241A),
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        const Icon(Icons.search, color: Color(0xFF22322D)),
      ],
    );
  }
}

/// 3. 绿色品牌宣传卡片
class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFFDDEDE6),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '宠托',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF02241A),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '给您安心的',
                  style: TextStyle(fontSize: 16, color: Color(0xFF4C5E58)),
                ),
                SizedBox(height: 4),
                Text(
                  '宠物服务',
                  style: TextStyle(fontSize: 11, color: Color(0xFF4C5E58)),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 130,
            height: 120,
            child: Stack(
              children: [
                Positioned(
                  right: 45,
                  top: 15,
                  child: Container(
                    width: 86,
                    height: 86,
                    decoration: const BoxDecoration(
                      color: Color(0xFFC8DED6),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 38,
                  child: Container(
                    width: 66,
                    height: 66,
                    decoration: const BoxDecoration(
                      color: Color(0xFFC8DED6),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  right: 40,
                  bottom: 2,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      color: Color(0xFFC8DED6),
                      shape: BoxShape.circle,
                    ),
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

/// 4. 服务入口网格
class _ServiceGrid extends StatelessWidget {
  const _ServiceGrid();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ServiceCard(
            title: '上门喂养',
            icon: Icons.pets_outlined,
            onTap: () => context.push('/order/create'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ServiceCard(
            title: '遛狗服务',
            icon: Icons.directions_walk,
            iconSize: 28,
            onTap: () => context.push('/order/create'),
          ),
        ),
      ],
    );
  }
}

/// 4.1 服务卡片通用样式
class _ServiceCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final double iconSize;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.title,
    required this.icon,
    this.iconSize = 30,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 122,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8E5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFFE7F4EF),
              child: Icon(icon, color: const Color(0xFF0A684F), size: iconSize),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontSize: 17, color: Color(0xFF0A2A20)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 5. 订单模块 (标题 + 动态卡片列表)
class _OrderSection extends StatefulWidget {
  const _OrderSection();

  @override
  State<_OrderSection> createState() => _OrderSectionState();
}

class _OrderSectionState extends State<_OrderSection> {
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = true;
  List<_HomeOrderItem> _orders = const [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    try {
      final response = await _apiClient.get<List<_HomeOrderItem>>(
        path: '/api/v1/orders/my',
        dataParser: (json) {
          final list = json as List<dynamic>;
          return list
              .map(
                (item) => _HomeOrderItem.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList();
        },
      );
      if (!mounted) return;
      if (response.isSuccess) {
        setState(() {
          _orders = (response.data ?? const []).take(2).toList();
          _isLoading = false;
        });
        return;
      }
      setState(() => _isLoading = false);
    } on ApiException {
      if (mounted) setState(() => _isLoading = false);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _reorder(String orderId) {
    context.push('/order/create?fromOrderId=$orderId');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '您已发布的订单',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0C2A20),
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.push('/orders'),
              child: const Text(
                '查看全部',
                style: TextStyle(fontSize: 15, color: Color(0xFF0C5D48)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF005A40)),
            ),
          )
        else if (_orders.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8E5)),
            ),
            child: const Text(
              '暂无订单，点击下方服务入口发布第一单',
              style: TextStyle(fontSize: 14, color: Color(0xFF5A6B62)),
            ),
          )
        else
          ..._orders.map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _OrderCard(
                petName: order.petNamesLabel,
                serviceType: order.serviceLabel,
                time: order.serviceDate,
                extraIcon: Icons.location_on_outlined,
                extraText: order.addressSnapshot,
                statusText: order.statusLabel,
                statusColor: order.statusColor,
                statusBgColor: order.statusBgColor,
                onTap: () => context.push('/order/${order.orderId}'),
                onReorder: () => _reorder(order.orderId),
              ),
            ),
          ),
      ],
    );
  }
}

class _HomeOrderItem {
  final String orderId;
  final String serviceDate;
  final String addressSnapshot;
  final int status;
  final List<_HomeOrderPet> pets;

  const _HomeOrderItem({
    required this.orderId,
    required this.serviceDate,
    required this.addressSnapshot,
    required this.status,
    required this.pets,
  });

  factory _HomeOrderItem.fromJson(Map<String, dynamic> json) {
    return _HomeOrderItem(
      orderId: json['orderId']?.toString() ?? '',
      serviceDate: json['serviceDate']?.toString() ?? '',
      addressSnapshot: json['addressSnapshot']?.toString() ?? '',
      status: _asInt(json['status']),
      pets:
          (json['pets'] as List?)
              ?.map(
                (item) => _HomeOrderPet.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList() ??
          const [],
    );
  }

  String get petNamesLabel =>
      pets.isEmpty ? '宠物服务' : pets.map((p) => p.petName).join('、');

  String get serviceLabel =>
      pets.isEmpty ? '上门服务' : pets.map((p) => p.petTypeDesc).join(' · ');

  String get statusLabel => switch (status) {
    1 => '悬赏中',
    2 => '待支付',
    3 => '待履约',
    4 => '履约中',
    5 => '待确认',
    6 => '已完成',
    7 => '履约受阻',
    8 => '异常结束',
    9 => '平台介入',
    _ => '进行中',
  };

  Color get statusColor => switch (status) {
    1 => const Color(0xFFEA865F),
    4 => const Color(0xFF005A40),
    6 => const Color(0xFF616161),
    7 => const Color(0xFF9C5A00),
    8 => const Color(0xFF616161),
    9 => const Color(0xFFB02A37),
    _ => const Color(0xFF005A40),
  };

  Color get statusBgColor => switch (status) {
    1 => const Color(0xFFFFF3EE),
    4 => const Color(0xFFE5F1ED),
    6 => const Color(0xFFEEEEEE),
    7 => const Color(0xFFFFF3E3),
    8 => const Color(0xFFF1F3F2),
    9 => const Color(0xFFFCE8EB),
    _ => const Color(0xFFE5F1ED),
  };

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _HomeOrderPet {
  final String petName;
  final String petTypeDesc;

  const _HomeOrderPet({required this.petName, required this.petTypeDesc});

  factory _HomeOrderPet.fromJson(Map<String, dynamic> json) {
    return _HomeOrderPet(
      petName: json['petName']?.toString() ?? '',
      petTypeDesc: json['petTypeDesc']?.toString() ?? '',
    );
  }
}

/// 5.1 通用动态订单卡片
class _OrderCard extends StatelessWidget {
  final String petName, serviceType, time, extraText, statusText;
  final IconData extraIcon;
  final Color statusColor, statusBgColor;
  final VoidCallback onTap;
  final VoidCallback? onReorder;

  const _OrderCard({
    required this.petName,
    required this.serviceType,
    required this.time,
    required this.extraIcon,
    required this.extraText,
    required this.statusText,
    required this.statusColor,
    required this.statusBgColor,
    required this.onTap,
    this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8E5), width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: Color(0xFFD4DBD8),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.pets, color: Color(0xFF4D5F59), size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        petName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF122A20),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusBgColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right,
                        color: Color(0xFFA3B1AC),
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    serviceType,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF586761),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 16,
                        color: Color(0xFF6A7571),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF455650),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(extraIcon, size: 16, color: const Color(0xFF6A7571)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          extraText,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF455650),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (onReorder != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: onReorder,
                        icon: const Icon(Icons.replay, size: 16),
                        label: const Text('再来一单'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF0C5D48),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
