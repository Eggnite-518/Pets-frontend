import 'package:flutter/material.dart';
import 'package:pets/features/owner/domain/entities/order_hard_filter_tag.dart';
import 'package:pets/features/owner/domain/entities/order_requirement_tags_data.dart';

import 'order_requirement_summary.dart';

/// 订单服务要求只读展示（需求标签 + 业务门槛 + 服务说明）。
class OrderServiceRequirementsCard extends StatelessWidget {
  final OrderRequirementTagsData requirementTags;
  final List<String> hardFilterTags;
  final String remark;

  const OrderServiceRequirementsCard({
    super.key,
    required this.requirementTags,
    this.hardFilterTags = const [],
    this.remark = '',
  });

  bool get hasContent =>
      requirementTags.isNotEmpty ||
      hardFilterTags.isNotEmpty ||
      remark.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!hasContent) {
      return const SizedBox.shrink();
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
          const Text(
            '服务要求',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A2621),
            ),
          ),
          const SizedBox(height: 12),
          OrderRequirementSummary(requirementTags: requirementTags),
          if (hardFilterTags.any(OrderHardFilterTag.isSafetyTag)) ...[
            const SizedBox(height: 4),
            _TagSection(
              title: '安全属性',
              labels: hardFilterTags
                  .where(OrderHardFilterTag.isSafetyTag)
                  .map((code) => OrderHardFilterTag.labels[code] ?? code)
                  .toList(),
            ),
          ],
          if (hardFilterTags.any(OrderHardFilterTag.isBusinessTag)) ...[
            const SizedBox(height: 12),
            _TagSection(
              title: '业务属性要求',
              labels: hardFilterTags
                  .where(OrderHardFilterTag.isBusinessTag)
                  .map((code) => OrderHardFilterTag.labels[code] ?? code)
                  .toList(),
            ),
          ],
          if (remark.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _TextBlock(title: '服务说明', value: remark.trim()),
          ],
        ],
      ),
    );
  }
}

class _TagSection extends StatelessWidget {
  final String title;
  final List<String> labels;

  const _TagSection({required this.title, required this.labels});

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
                    color: const Color(0xFFFFF8ED),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE9820A).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF7A4A00),
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

class _TextBlock extends StatelessWidget {
  final String title;
  final String value;

  const _TextBlock({required this.title, required this.value});

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
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF1A2621),
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
