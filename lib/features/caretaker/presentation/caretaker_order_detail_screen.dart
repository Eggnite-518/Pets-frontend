import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:pets/core/network/api_client.dart';
import 'package:pets/core/widgets/order_requirement_summary.dart';
import 'package:pets/features/owner/domain/entities/order_requirement_tags_data.dart';

import '../data/datasources/caretaker_dashboard_remote_data_source.dart';
import '../data/datasources/fulfillment_remote_data_source.dart';
import '../data/datasources/order_hall_remote_data_source.dart';
import '../data/repositories/caretaker_dashboard_repository_impl.dart';
import '../data/repositories/fulfillment_repository_impl.dart';
import '../data/repositories/order_hall_repository_impl.dart';
import '../domain/entities/caretaker_order_detail.dart';
import '../domain/usecases/apply_order_use_case.dart';
import '../domain/usecases/get_caretaker_order_detail_use_case.dart';
import '../domain/usecases/no_fault_retreat_use_case.dart';
import 'caretaker_applied_orders.dart';
import 'caretaker_home_screen.dart';
import 'deposit_flow_helper.dart';

class CaretakerOrderDetailScreen extends StatefulWidget {
  const CaretakerOrderDetailScreen({
    super.key,
    required this.orderId,
    this.initialHasApplied = false,
  });

  final String orderId;
  final bool initialHasApplied;

  @override
  State<CaretakerOrderDetailScreen> createState() =>
      _CaretakerOrderDetailScreenState();
}

class _CaretakerOrderDetailScreenState
    extends State<CaretakerOrderDetailScreen> {
  late final GetCaretakerOrderDetailUseCase _getDetailUseCase;
  late final ApplyOrderUseCase _applyOrderUseCase;
  late final NoFaultRetreatUseCase _noFaultRetreatUseCase;

  CaretakerOrderDetail? _detail;
  bool _isLoading = true;
  bool _isApplying = false;
  bool _isSubmittingNoFaultRetreat = false;
  bool _localHasApplied = false;
  String? _errorMessage;
  Timer? _statusPollTimer;

  @override
  void initState() {
    super.initState();
    _localHasApplied =
        widget.initialHasApplied ||
        CaretakerAppliedOrders.instance.contains(widget.orderId);
    final client = ApiClient();
    final dataSource = CaretakerDashboardRemoteDataSource(client);
    final repo = CaretakerDashboardRepositoryImpl(dataSource);
    _getDetailUseCase = GetCaretakerOrderDetailUseCase(repo);
    final hallRepo = OrderHallRepositoryImpl(OrderHallRemoteDataSource(client));
    _applyOrderUseCase = ApplyOrderUseCase(hallRepo);
    _noFaultRetreatUseCase = NoFaultRetreatUseCase(
      FulfillmentRepositoryImpl(
        FulfillmentRemoteDataSource(client, http.Client()),
      ),
    );
    _load();
  }

  @override
  void dispose() {
    _statusPollTimer?.cancel();
    super.dispose();
  }

  void _syncStatusPolling(int orderStatus) {
    _statusPollTimer?.cancel();
    _statusPollTimer = null;
    if (orderStatus != 5) return;
    _statusPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _load(silent: true);
    });
  }

  Future<void> _load({bool silent = false}) async {
    final previousStatus = _detail?.orderStatus;
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    final result = await _getDetailUseCase(widget.orderId);
    if (!mounted) return;
    result.when(
      success: (detail) {
        if (previousStatus == 5 && detail.orderStatus == 6) {
          CaretakerHomeScreen.requestApplicationsRefresh();
        }
        setState(() {
          _detail = detail;
          if (detail.hasApplied) {
            _localHasApplied = true;
            CaretakerAppliedOrders.instance.add(detail.orderId);
          }
          if (!silent) {
            _isLoading = false;
          }
        });
        _syncStatusPolling(detail.orderStatus);
      },
      failure: (error) {
        if (!silent) {
          setState(() {
            _errorMessage = error.message;
            _isLoading = false;
          });
        }
      },
    );
  }

  Future<void> _apply() async {
    if (_isApplying) return;
    setState(() => _isApplying = true);
    final result = await _applyOrderUseCase(widget.orderId);
    if (!mounted) return;
    setState(() => _isApplying = false);
    result.when(
      success: (_) {
        setState(() => _localHasApplied = true);
        CaretakerAppliedOrders.instance.add(widget.orderId);
        CaretakerHomeScreen.requestApplicationsRefresh();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('报名成功，等待宠物主确认'),
            backgroundColor: Color(0xFF004D36),
          ),
        );
        _load();
      },
      failure: (error) async {
        final alreadyApplied = error.message.contains('已报名');
        if (alreadyApplied) {
          setState(() => _localHasApplied = true);
          CaretakerAppliedOrders.instance.add(widget.orderId);
          CaretakerHomeScreen.requestApplicationsRefresh();
          _load();
        } else if (isDepositRelatedError(error)) {
          await showDepositRequiredDialog(context, message: error.message);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(alreadyApplied ? '您已报名该订单' : error.message),
            backgroundColor: alreadyApplied
                ? const Color(0xFF004D36)
                : Colors.red,
          ),
        );
      },
    );
  }

  Future<void> _openDisputes() async {
    await context.push('/caretaker/order/${widget.orderId}/disputes');
  }

  Future<void> _openServiceCheckIn(CaretakerOrderDetail detail) async {
    final changed = await context.push<bool>(
      '/caretaker/service/${widget.orderId}',
      extra: detail.checklistNodeTypes,
    );
    if (!mounted) return;
    if (changed == true) {
      CaretakerHomeScreen.requestApplicationsRefresh();
    }
    await _load();
  }

  Future<void> _submitNoFaultRetreat() async {
    if (_isSubmittingNoFaultRetreat) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('申请无责撤退？'),
        content: const Text(
          '若宠主超过 30 分钟仍未处理异常，可按规则申请无责撤退。若尚未达到等待时长，系统会拦截本次申请。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认申请'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSubmittingNoFaultRetreat = true);
    final result = await _noFaultRetreatUseCase(widget.orderId);
    if (!mounted) return;
    setState(() => _isSubmittingNoFaultRetreat = false);

    result.when(
      success: (_) async {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无责撤退申请已提交，订单已按异常结束处理')));
        await _load();
      },
      failure: (error) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      },
    );
  }

  bool _hasApplied(CaretakerOrderDetail detail) =>
      detail.hasApplied || _localHasApplied;

  Widget? _buildBottomBar(CaretakerOrderDetail detail) {
    if (detail.orderStatus == 1) {
      final applied = _hasApplied(detail);
      return Container(
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.of(context).padding.bottom + 12,
        ),
        child: FilledButton(
          onPressed: applied || _isApplying ? null : _apply,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF004D36),
            disabledBackgroundColor: const Color(0xFFE8F2EF),
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          child: _isApplying
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  applied ? '已报名' : '立即报名',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: applied ? const Color(0xFF8BA49A) : Colors.white,
                  ),
                ),
        ),
      );
    }
    if (detail.orderStatus == 3 || detail.orderStatus == 4) {
      return Container(
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.of(context).padding.bottom + 12,
        ),
        child: FilledButton(
          onPressed: () => _openServiceCheckIn(detail),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF004D36),
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          child: const Text(
            '进入打卡',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
    if (detail.orderStatus == 5 || detail.orderStatus == 6) {
      return Container(
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.of(context).padding.bottom + 12,
        ),
        child: OutlinedButton(
          onPressed: () => _openServiceCheckIn(detail),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF004D36),
            side: const BorderSide(color: Color(0xFF9BC7B4)),
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          child: const Text(
            '查看打卡记录',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
    if (detail.orderStatus == 7) {
      return Container(
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.of(context).padding.bottom + 12,
        ),
        child: FilledButton(
          onPressed: _isSubmittingNoFaultRetreat ? null : _submitNoFaultRetreat,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF8B3A2B),
            disabledBackgroundColor: const Color(0xFFE8D8D3),
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          child: _isSubmittingNoFaultRetreat
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  '申请无责撤退',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
        ),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F3F5),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A2621)),
        title: const Text(
          '订单详情',
          style: TextStyle(
            color: Color(0xFF1A2621),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (detail != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _StatusTag(detail.orderStatus, detail.orderStatusText),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF004D36)),
            )
          : _errorMessage != null
          ? _ErrorView(message: _errorMessage!, onRetry: _load)
          : detail == null
          ? const SizedBox()
          : _DetailBody(
              detail: detail,
              onRefresh: _load,
              onOpenDisputes: _openDisputes,
              onNoFaultRetreat: _submitNoFaultRetreat,
              isSubmittingNoFaultRetreat: _isSubmittingNoFaultRetreat,
            ),
      bottomNavigationBar:
          detail != null && !_isLoading && _errorMessage == null
          ? _buildBottomBar(detail)
          : null,
    );
  }
}

// ─── 状态小标签 ───────────────────────────────────────────────────────────────

class _StatusTag extends StatelessWidget {
  final int status;
  final String text;
  const _StatusTag(this.status, this.text);

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      1 => (const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
      3 => (const Color(0xFFE3F2FD), const Color(0xFF1565C0)),
      4 => (const Color(0xFFE8F2EF), const Color(0xFF004D36)),
      5 => (const Color(0xFFFFF8E1), const Color(0xFF996600)),
      6 => (const Color(0xFFEEEEEE), const Color(0xFF616161)),
      7 => (const Color(0xFFFFF3E3), const Color(0xFF9C5A00)),
      8 => (const Color(0xFFF1F3F2), const Color(0xFF5A6B62)),
      9 => (const Color(0xFFFCE8EB), const Color(0xFFB02A37)),
      _ => (const Color(0xFFEEEEEE), const Color(0xFF616161)),
    };
    final label = text.isNotEmpty ? text : _fallback(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  String _fallback(int s) => switch (s) {
    1 => '悬赏中',
    3 => '待上门',
    4 => '履约中',
    5 => '待确认',
    6 => '已完成',
    7 => '履约受阻',
    8 => '异常结束',
    9 => '平台介入',
    _ => '进行中',
  };
}

// ─── 主体 ─────────────────────────────────────────────────────────────────────

class _DetailBody extends StatelessWidget {
  final CaretakerOrderDetail detail;
  final RefreshCallback onRefresh;
  final VoidCallback onOpenDisputes;
  final VoidCallback onNoFaultRetreat;
  final bool isSubmittingNoFaultRetreat;

  const _DetailBody({
    required this.detail,
    required this.onRefresh,
    required this.onOpenDisputes,
    required this.onNoFaultRetreat,
    required this.isSubmittingNoFaultRetreat,
  });

  @override
  Widget build(BuildContext context) {
    final petName = detail.pets.isNotEmpty ? detail.pets.first.petName : null;

    return RefreshIndicator(
      color: const Color(0xFF004D36),
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 宠主信息块 ──────────────────────────────────
            _OwnerSection(
              owner: detail.owner,
              orderId: detail.orderId,
              orderStatus: detail.orderStatus,
              petName: petName,
            ),
            const _BlockDivider(),

            // ── 订单信息 ────────────────────────────────────
            _InfoBlock(
              rows: [
                _RowData(
                  '服务类型',
                  detail.serviceItems.map((s) => s.serviceTypeText).join(' · '),
                ),
                _RowData('服务日期', detail.serviceDate),
                _RowData('服务时段', detail.serviceTimeSlot),
                _RowData(
                  '订单金额',
                  '¥${detail.totalAmount}',
                  valueStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF003827),
                  ),
                ),
              ],
            ),
            const _BlockDivider(),

            // ── 服务地址 ────────────────────────────────────
            _AddressBlock(
              address: detail.address,
              distanceKm: detail.distanceKm,
            ),
            const _BlockDivider(),

            // ── 宠物档案 ────────────────────────────────────
            if (detail.pets.isNotEmpty) ...[
              _PetsBlock(pets: detail.pets),
              const _BlockDivider(),
            ],

            // ── 服务需求清单 ────────────────────────────────
            if (detail.requirementTags.isNotEmpty) ...[
              _RequirementTagsBlock(requirementTags: detail.requirementTags),
              const _BlockDivider(),
            ],

            // ── 特殊说明 ────────────────────────────────────
            if (detail.serviceNotes.isNotEmpty) ...[
              _NoteBlock(note: detail.serviceNotes),
              const _BlockDivider(),
            ],

            if (detail.orderStatus == 5 || detail.orderStatus == 6) ...[
              _OwnerConfirmationBlock(orderStatus: detail.orderStatus),
              const _BlockDivider(),
            ],

            if (detail.orderStatus >= 7) ...[
              _ExceptionStatusBlock(
                orderStatus: detail.orderStatus,
                onNoFaultRetreat: onNoFaultRetreat,
                isSubmittingNoFaultRetreat: isSubmittingNoFaultRetreat,
              ),
              const _BlockDivider(),
            ],

            if (detail.orderStatus >= 3) ...[
              _DisputeEntryBlock(onTap: onOpenDisputes),
              const _BlockDivider(),
            ],

            // ── 订单号 + 下单时间（页脚信息）──────────────
            _FooterInfo(orderId: detail.orderId, createdAt: detail.createdAt),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

// ─── 宠主信息块 ──────────────────────────────────────────────────────────────

class _OwnerSection extends StatelessWidget {
  final OrderOwnerInfo owner;
  final String orderId;
  final int orderStatus; // kept for potential future use
  final String? petName;

  const _OwnerSection({
    required this.owner,
    required this.orderId,
    required this.orderStatus,
    this.petName,
  });

  void _onAvatarTap(BuildContext context) {
    final buf = StringBuffer('/caretaker/messages/$orderId?');
    buf.write('peerName=${Uri.encodeComponent(owner.nickname)}');
    if (owner.avatarUrl.isNotEmpty) {
      buf.write('&peerAvatarUrl=${Uri.encodeComponent(owner.avatarUrl)}');
    }
    if (petName != null && petName!.isNotEmpty) {
      buf.write('&petName=${Uri.encodeComponent(petName!)}');
    }
    buf.write('&orderId=$orderId');
    context.push(buf.toString());
  }

  @override
  Widget build(BuildContext context) {
    final hasAvatar = owner.avatarUrl.isNotEmpty;
    final initials = owner.nickname.isNotEmpty
        ? owner.nickname.characters.first
        : '?';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          // 头像（始终可点击进入聊天）
          GestureDetector(
            onTap: () => _onAvatarTap(context),
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFFE8F2EF),
                  backgroundImage: hasAvatar
                      ? NetworkImage(owner.avatarUrl)
                      : null,
                  child: hasAvatar
                      ? null
                      : Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF004D36),
                          ),
                        ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Color(0xFF004D36),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chat_bubble_rounded,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // 昵称
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  owner.nickname.isNotEmpty ? owner.nickname : '宠物主',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2621),
                  ),
                ),
                if (owner.phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    owner.phone,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8BA49A),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 通用信息行列表块 ─────────────────────────────────────────────────────────

class _RowData {
  final String label;
  final String value;
  final TextStyle? valueStyle;
  const _RowData(this.label, this.value, {this.valueStyle});
}

class _InfoBlock extends StatelessWidget {
  final List<_RowData> rows;
  const _InfoBlock({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final isLast = entry.key == rows.length - 1;
          final row = entry.value;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 68,
                  child: Text(
                    row.label,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    row.value.isNotEmpty ? row.value : '--',
                    style:
                        row.valueStyle ??
                        const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1A2621),
                        ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── 服务地址块 ──────────────────────────────────────────────────────────────

class _AddressBlock extends StatelessWidget {
  final OrderAddress address;
  final double? distanceKm;
  const _AddressBlock({required this.address, this.distanceKm});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.location_on_outlined,
            size: 18,
            color: Color(0xFF004D36),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  address.fullAddress.isNotEmpty ? address.fullAddress : '--',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A2621),
                    height: 1.4,
                  ),
                ),
                if (distanceKm != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      '距您约 $distanceKm km',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9E9E9E),
                      ),
                    ),
                  )
                else if (address.district.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      address.district,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9E9E9E),
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

// ─── 宠物档案块 ──────────────────────────────────────────────────────────────

class _PetsBlock extends StatelessWidget {
  final List<OrderPetInfo> pets;
  const _PetsBlock({required this.pets});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        children: pets.asMap().entries.map((entry) {
          final isLast = entry.key == pets.length - 1;
          return _PetRow(pet: entry.value, isLast: isLast);
        }).toList(),
      ),
    );
  }
}

class _PetRow extends StatelessWidget {
  final OrderPetInfo pet;
  final bool isLast;
  const _PetRow({required this.pet, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final hasAvatar = pet.avatarUrl.isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFE8F2EF),
            backgroundImage: hasAvatar ? NetworkImage(pet.avatarUrl) : null,
            child: hasAvatar
                ? null
                : Icon(
                    pet.petType == 2
                        ? Icons.pets_rounded
                        : Icons.cruelty_free_rounded,
                    size: 20,
                    color: const Color(0xFF004D36),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      pet.petName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A2621),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      [
                        if (pet.petTypeText.isNotEmpty) pet.petTypeText,
                        if (pet.breed.isNotEmpty) pet.breed,
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9E9E9E),
                      ),
                    ),
                  ],
                ),
                if (pet.profileTags.displayLabels.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: pet.profileTags.displayLabels.map((label) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F2EF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF004D36),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                if (pet.careNotes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    pet.careNotes,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF5A6B62),
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 服务需求清单块 ──────────────────────────────────────────────────────────

class _RequirementTagsBlock extends StatelessWidget {
  final OrderRequirementTagsData requirementTags;

  const _RequirementTagsBlock({required this.requirementTags});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '服务需求清单',
            style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
          ),
          const SizedBox(height: 10),
          OrderRequirementSummary(requirementTags: requirementTags),
        ],
      ),
    );
  }
}

// ─── 特殊说明块 ──────────────────────────────────────────────────────────────

class _NoteBlock extends StatelessWidget {
  final String note;
  const _NoteBlock({required this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '特殊说明',
            style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
          ),
          const SizedBox(height: 6),
          Text(
            note,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF3B564A),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerConfirmationBlock extends StatelessWidget {
  final int orderStatus;

  const _OwnerConfirmationBlock({required this.orderStatus});

  @override
  Widget build(BuildContext context) {
    final isCompleted = orderStatus == 6;
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.hourglass_top_rounded,
            color: isCompleted
                ? const Color(0xFF004D36)
                : const Color(0xFF9C5A00),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCompleted ? '宠主已确认完成' : '等待宠主确认',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2621),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isCompleted
                      ? '本单已完成结算，收入将计入你的钱包。'
                      : '全部打卡已完成，宠主确认后平台会立即结算。',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF5A6B62),
                    height: 1.5,
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

class _ExceptionStatusBlock extends StatelessWidget {
  final int orderStatus;
  final VoidCallback onNoFaultRetreat;
  final bool isSubmittingNoFaultRetreat;

  const _ExceptionStatusBlock({
    required this.orderStatus,
    required this.onNoFaultRetreat,
    required this.isSubmittingNoFaultRetreat,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, title, message, accent) = switch (orderStatus) {
      7 => (
        Icons.warning_amber_rounded,
        '履约受阻，等待宠主处理',
        '系统已联系宠主确认异常情况。若宠主超过 30 分钟仍未处理，可尝试申请无责撤退；若尚未达到等待时长，后端会拦截本次申请。',
        const Color(0xFF9C5A00),
      ),
      8 => (
        Icons.assignment_late_outlined,
        '订单已异常结束',
        '本单已按无责撤退规则处理，平台会根据结算规则完成补偿与退款。',
        const Color(0xFF5A6B62),
      ),
      9 => (
        Icons.sos_outlined,
        '平台已介入紧急事件',
        '你的紧急求助已经提交成功，请优先保证人身安全并保留现场证据，等待平台进一步处理。',
        const Color(0xFFB02A37),
      ),
      _ => (
        Icons.info_outline,
        '订单处理中',
        '请根据最新状态继续处理当前订单。',
        const Color(0xFF5A6B62),
      ),
    };

    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2621),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF5A6B62),
              height: 1.6,
            ),
          ),
          if (orderStatus == 7) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isSubmittingNoFaultRetreat ? null : onNoFaultRetreat,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8B3A2B),
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              icon: isSubmittingNoFaultRetreat
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.exit_to_app_rounded, size: 18),
              label: Text(
                isSubmittingNoFaultRetreat ? '处理中...' : '申请无责撤退',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DisputeEntryBlock extends StatelessWidget {
  final VoidCallback onTap;

  const _DisputeEntryBlock({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F2EF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.gavel_outlined,
                  color: Color(0xFF004D36),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '申诉与仲裁',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A2621),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '对系统判责、异常扣款或履约争议有异议时，可补充说明并查看平台处理结果。',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8BA49A),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFC3D5CC)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 页脚信息 ────────────────────────────────────────────────────────────────

class _FooterInfo extends StatelessWidget {
  final String orderId;
  final String createdAt;
  const _FooterInfo({required this.orderId, required this.createdAt});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          _FooterRow(label: '订单编号', value: orderId),
          const SizedBox(height: 4),
          _FooterRow(label: '下单时间', value: createdAt),
        ],
      ),
    );
  }
}

class _FooterRow extends StatelessWidget {
  final String label;
  final String value;
  const _FooterRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label：',
          style: const TextStyle(fontSize: 12, color: Color(0xFFB0B0B0)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, color: Color(0xFFB0B0B0)),
          ),
        ),
      ],
    );
  }
}

// ─── 分隔线 ──────────────────────────────────────────────────────────────────

class _BlockDivider extends StatelessWidget {
  const _BlockDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 8, color: const Color(0xFFF2F3F5));
  }
}

// ─── 错误视图 ─────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: const TextStyle(fontSize: 14, color: Color(0xFF9E9E9E)),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
