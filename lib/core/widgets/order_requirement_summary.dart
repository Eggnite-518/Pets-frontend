import 'package:flutter/material.dart';
import 'package:pets/features/owner/domain/entities/order_requirement_tag.dart';
import 'package:pets/features/owner/domain/entities/order_requirement_tags_data.dart';

/// 订单需求标签（物品引导 / 环境交代 / 视频打卡 / 服务选项）展示卡片。
class OrderRequirementSummary extends StatelessWidget {
  final OrderRequirementTagsData requirementTags;

  const OrderRequirementSummary({
    super.key,
    required this.requirementTags,
  });

  bool get _hasVisibleContent =>
      requirementTags.tags.isNotEmpty ||
      requirementTags.accessNote.trim().isNotEmpty ||
      requirementTags.emergencyContactName.trim().isNotEmpty ||
      requirementTags.emergencyContactPhone.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!_hasVisibleContent) {
      return const SizedBox.shrink();
    }

    final groupedTags = <String, List<String>>{};
    for (final tag in requirementTags.tags) {
      final category = OrderRequirementTag.categoryOf(tag);
      groupedTags.putIfAbsent(category, () => []).add(tag);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final category in const [
          'ITEM_GUIDE',
          'ENVIRONMENT',
          'VIDEO_CHECKIN',
          'SERVICE_OPTION',
        ])
          if (groupedTags[category]?.isNotEmpty ?? false) ...[
            _Section(
              title: OrderRequirementTag.categoryTitles[category] ?? category,
              labels: OrderRequirementTag.describeTags(groupedTags[category]!),
            ),
            const SizedBox(height: 12),
          ],
        if (requirementTags.accessNote.trim().isNotEmpty)
          _TextRow(title: '门禁说明', value: requirementTags.accessNote),
        if (requirementTags.emergencyContactName.trim().isNotEmpty ||
            requirementTags.emergencyContactPhone.trim().isNotEmpty)
          _TextRow(
            title: '紧急联系人',
            value:
                '${requirementTags.emergencyContactName} ${requirementTags.emergencyContactPhone}'
                    .trim(),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<String> labels;

  const _Section({required this.title, required this.labels});

  @override
  Widget build(BuildContext context) {
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
          children: labels
              .map(
                (label) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F2EF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF004D36),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _TextRow extends StatelessWidget {
  final String title;
  final String value;

  const _TextRow({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
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
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF1A2621),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
