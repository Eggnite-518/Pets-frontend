import 'package:flutter/material.dart';
import 'package:pets/features/owner/domain/entities/order_address.dart';
import 'package:pets/features/owner/domain/entities/order_hard_filter_tag.dart';
import 'package:pets/features/owner/domain/entities/order_quote.dart';
import 'package:pets/features/owner/domain/entities/order_quote_item.dart';
import 'package:pets/features/owner/domain/entities/order_requirement_tag.dart';
import 'package:pets/features/owner/domain/entities/order_requirement_tags_data.dart';

class Step3FeeConfirm extends StatefulWidget {
  final String initialFinalAmount;
  final OrderQuote? quote;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetryQuote;
  final ValueChanged<String> onFinalAmountChanged;
  final ValueChanged<bool> onPriceValidityChanged;
  final int serviceType;
  final String serviceDate;
  final String serviceStartTime;
  final String serviceEndTime;
  final OrderAddress? selectedAddress;
  final List<String> hardFilterTags;
  final OrderRequirementTagsData requirementTags;
  final String remark;

  const Step3FeeConfirm({
    super.key,
    required this.initialFinalAmount,
    required this.quote,
    required this.isLoading,
    required this.onRetryQuote,
    required this.onFinalAmountChanged,
    required this.onPriceValidityChanged,
    required this.serviceType,
    required this.serviceDate,
    required this.serviceStartTime,
    required this.serviceEndTime,
    this.selectedAddress,
    this.errorMessage,
    this.hardFilterTags = const [],
    this.requirementTags = const OrderRequirementTagsData(),
    this.remark = '',
  });

  @override
  State<Step3FeeConfirm> createState() => _Step3FeeConfirmState();
}

class _Step3FeeConfirmState extends State<Step3FeeConfirm> {
  static const String _priceProtectionMessage = '订单价格低于行业底价保护标准，请调整。';

  double _manualAdjustment = 0.0;
  String? _lastNotifiedFinalAmount;
  bool? _lastNotifiedPriceValidity;

  List<OrderQuoteItem> get _visiblePriceItems {
    return (widget.quote?.priceItems ?? const [])
        .where((item) => _shouldDisplayPriceItem(item))
        .toList();
  }

  bool _shouldDisplayPriceItem(OrderQuoteItem item) {
    if (item.quantity > 0) return true;
    return item.itemName == '基础上门费' || item.itemName == '距离附加费';
  }

  double get _quoteTotal {
    final visibleItems = _visiblePriceItems;
    if (visibleItems.isNotEmpty) {
      return visibleItems.fold<double>(
        0.0,
        (total, item) => total + _priceItemTotal(item),
      );
    }
    return double.tryParse(
          widget.quote?.totalAmount ?? widget.initialFinalAmount,
        ) ??
        0.0;
  }

  double get _finalAmount =>
      (_quoteTotal + _manualAdjustment).clamp(0.0, double.infinity);

  double get _minimumFinalAmount => _quoteTotal * 0.6;

  bool get _isFinalAmountValid =>
      _quoteTotal <= 0 || _finalAmount >= _minimumFinalAmount;

  bool get _hasRequirementSummary {
    return widget.requirementTags.tags.isNotEmpty ||
        widget.requirementTags.accessNote.trim().isNotEmpty ||
        widget.requirementTags.emergencyContactName.trim().isNotEmpty ||
        widget.requirementTags.emergencyContactPhone.trim().isNotEmpty ||
        widget.hardFilterTags.isNotEmpty ||
        widget.remark.trim().isNotEmpty;
  }

  Widget _buildRequirementSummaryCard() {
    final groupedTags = <String, List<String>>{};
    for (final tag in widget.requirementTags.tags) {
      final category = OrderRequirementTag.categoryOf(tag);
      groupedTags.putIfAbsent(category, () => []).add(tag);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEBEBEB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final category in [
            'ITEM_GUIDE',
            'ENVIRONMENT',
            'VIDEO_CHECKIN',
            'SERVICE_OPTION',
          ])
            if (groupedTags[category]?.isNotEmpty ?? false) ...[
              _buildSummarySection(
                OrderRequirementTag.categoryTitles[category] ?? category,
                OrderRequirementTag.describeTags(groupedTags[category]!),
              ),
              const SizedBox(height: 12),
            ],
          if (widget.requirementTags.accessNote.trim().isNotEmpty)
            _buildSummaryTextRow('门禁说明', widget.requirementTags.accessNote),
          if (widget.requirementTags.emergencyContactName.trim().isNotEmpty ||
              widget.requirementTags.emergencyContactPhone.trim().isNotEmpty)
            _buildSummaryTextRow(
              '紧急联系人',
              '${widget.requirementTags.emergencyContactName} ${widget.requirementTags.emergencyContactPhone}'
                  .trim(),
            ),
          if (widget.hardFilterTags.any(OrderHardFilterTag.isSafetyTag))
            _buildSummarySection(
              '安全属性',
              widget.hardFilterTags
                  .where(OrderHardFilterTag.isSafetyTag)
                  .map((code) => OrderHardFilterTag.labels[code] ?? code)
                  .toList(),
            ),
          if (widget.hardFilterTags.any(OrderHardFilterTag.isBusinessTag)) ...[
            if (widget.hardFilterTags.any(OrderHardFilterTag.isSafetyTag))
              const SizedBox(height: 12),
            _buildSummarySection(
              '业务属性',
              widget.hardFilterTags
                  .where(OrderHardFilterTag.isBusinessTag)
                  .map((code) => OrderHardFilterTag.labels[code] ?? code)
                  .toList(),
            ),
          ],
          if (widget.remark.trim().isNotEmpty)
            _buildSummaryTextRow('服务说明', widget.remark),
        ],
      ),
    );
  }

  Widget _buildSummarySection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF5A6B62),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items
              .map(
                (item) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F2EF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF004D36)),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildSummaryTextRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5A6B62),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 14, color: Color(0xFF1A2621), height: 1.4),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _notifyFinalAmountChanged();
  }

  @override
  void didUpdateWidget(covariant Step3FeeConfirm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quote != widget.quote ||
        oldWidget.initialFinalAmount != widget.initialFinalAmount) {
      _notifyFinalAmountChanged();
    }
  }

  void _updateFinalAmount() {
    _notifyFinalAmountChanged();
  }

  void _notifyFinalAmountChanged() {
    final amount = _finalAmount.toStringAsFixed(2);
    if (_lastNotifiedFinalAmount != amount) {
      _lastNotifiedFinalAmount = amount;
      widget.onFinalAmountChanged(amount);
    }
    _notifyPriceValidityChanged();
  }

  void _notifyPriceValidityChanged() {
    final isValid = _isFinalAmountValid;
    if (_lastNotifiedPriceValidity == isValid) return;
    final wasValid = _lastNotifiedPriceValidity;
    _lastNotifiedPriceValidity = isValid;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onPriceValidityChanged(isValid);
      if (!isValid && wasValid != false) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text(_priceProtectionMessage)),
          );
      }
    });
  }

  double _priceItemTotal(OrderQuoteItem item) {
    final itemAmount = double.tryParse(item.amount) ?? 0.0;
    final quantity = item.quantity < 0 ? 0 : item.quantity;
    return itemAmount * quantity;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. 顶部订单信息确认卡片
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEBEBEB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 绿底标签
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF004D36),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.serviceType == 1 ? '上门遛狗' : '上门喂猫',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 时间信息
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: Color(0xFF5A6B62),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '预约时间',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8BA49A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.serviceDate,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF1A2621),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.serviceStartTime} - ${widget.serviceEndTime}',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF1A2621),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 地址信息
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: Color(0xFF5A6B62),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '服务地址',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8BA49A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.selectedAddress?.fullAddress ?? '请选择服务地址',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF1A2621),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        if (_hasRequirementSummary) ...[
          const Text(
            '需求清单预览',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A2621),
            ),
          ),
          const SizedBox(height: 12),
          _buildRequirementSummaryCard(),
          const SizedBox(height: 24),
        ],

        // 2. 费用清单标题
        const Text(
          '费用清单',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A2621),
          ),
        ),
        const SizedBox(height: 16),

        if (widget.isLoading) ...[
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在获取预估费用...'),
                ],
              ),
            ),
          ),
        ] else if (widget.errorMessage != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F0),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF6D2CF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '获取报价失败',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB02A37),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.errorMessage!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF5A5560),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: widget.onRetryQuote,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF004D36),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('重新获取报价'),
                ),
              ],
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEBEBEB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.quote != null) ...[
                  ..._visiblePriceItems.map(_buildPriceItemRow),
                  const SizedBox(height: 20),
                ],
                _buildFeeRow('手动调整', _manualAdjustment, (val) {
                  setState(() {
                    _manualAdjustment = val;
                    _updateFinalAmount();
                  });
                }),
                if (!_isFinalAmountValid) ...[
                  const SizedBox(height: 10),
                  const Text(
                    _priceProtectionMessage,
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFFB02A37),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(
                    color: Color(0xFFEBEBEB),
                    height: 1,
                    thickness: 1,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      '合计金额',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A2621),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        const Text(
                          'RMB ',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF5A6B62),
                          ),
                        ),
                        Text(
                          _finalAmount.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF004D36),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),

        // 4. 信任保障徽章 (两列并排)
        Row(
          children: [
            Expanded(
              child: _buildTrustBadge(Icons.shield_outlined, '平安保险', '全程意外承保'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTrustBadge(
                Icons.account_balance_wallet_outlined,
                '资金托管',
                '确认收货后结算',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 5. 橘色防骗提示条
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF6F2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFCE6DD)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline,
                color: Color(0xFFF06A42),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: const Text(
                  '温馨提示：为了您的财产安全，请勿脱离平台进行私下交易。平台将为您提供全程服务监管与保障。',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4A4A4A),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 6. 底部安全连接状态
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF659A83),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  '正在连接安全支付网关...',
                  style: TextStyle(fontSize: 12, color: Color(0xFF5A6B62)),
                ),
              ],
            ),
            Row(
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 14,
                  color: Color(0xFF5A6B62),
                ),
                const SizedBox(width: 4),
                const Text(
                  'SECURE PAYMENT',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF5A6B62),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // 构建带加减号的单行费用组件
  Widget _buildPriceItemRow(OrderQuoteItem item) {
    final itemAmount = _priceItemTotal(item);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF1A2621),
                  ),
                ),
                if (item.remark.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.remark,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8BA49A),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '¥${itemAmount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF004D36),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeRow(
    String title,
    double currentVal,
    Function(double) onChanged,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, color: Color(0xFF1A2621)),
        ),
        Row(
          children: [
            // 减号
            InkWell(
              onTap: () {
                final nextValue = (currentVal - 5.0)
                    .clamp(-_quoteTotal, double.infinity)
                    .toDouble();
                onChanged(nextValue);
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F6F5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.remove,
                  size: 18,
                  color: Color(0xFF8BA49A),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // 金额显示
            SizedBox(
              width: 68,
              child: Text(
                '¥${currentVal.toStringAsFixed(2)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A2621),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // 加号
            InkWell(
              onTap: () => onChanged(currentVal + 5.0),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F6F5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add,
                  size: 18,
                  color: Color(0xFF8BA49A),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 构建安全保障小徽章
  Widget _buildTrustBadge(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEBEBEB)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F2EF),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF004D36), size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF004D36),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Color(0xFF8BA49A)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
