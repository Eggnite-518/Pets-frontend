import 'package:flutter/material.dart';

import '../../domain/entities/provider_detail.dart';

Future<void> showProviderQualificationSheet(
  BuildContext context,
  ProviderDetail detail,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.58,
        minChildSize: 0.42,
        maxChildSize: 0.9,
        builder: (_, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5D0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '职业资格档案',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A2621),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: const Color(0xFFE8F2EF),
                      backgroundImage: detail.providerAvatarUrl.isNotEmpty
                          ? NetworkImage(detail.providerAvatarUrl)
                          : null,
                      child: detail.providerAvatarUrl.isEmpty
                          ? const Icon(Icons.person, color: Color(0xFF004D36))
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            detail.providerNickname.isEmpty
                                ? '宠托师'
                                : detail.providerNickname,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (detail.levelTag.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              detail.levelTag,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF004D36),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        label: '信用分',
                        value: '${detail.creditScore}',
                        icon: Icons.verified_user_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricTile(
                        label: '履约合规率',
                        value: '${detail.complianceRate.toStringAsFixed(1)}%',
                        icon: Icons.task_alt_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        label: '综合评分',
                        value: detail.rating.toStringAsFixed(1),
                        icon: Icons.star_outline_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricTile(
                        label: '历史总单',
                        value: '${detail.totalOrderCount}',
                        icon: Icons.history_rounded,
                      ),
                    ),
                  ],
                ),
                if (detail.certLabels.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text(
                    '资质认证',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A2621),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: detail.certLabels
                        .map(
                          (label) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F2EF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              label,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF004D36),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 20),
                const Text(
                  '服务概况',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2621),
                  ),
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  label: '距离服务地址',
                  value: '${detail.distanceKm.toStringAsFixed(1)} 公里',
                ),
                _InfoRow(
                  label: '历史评价',
                  value: '${detail.reviewCount} 条',
                ),
                if (detail.petName.isNotEmpty)
                  _InfoRow(label: '本次服务宠物', value: detail.petName),
                if (detail.serviceItems.isNotEmpty)
                  _InfoRow(
                    label: '服务内容',
                    value: detail.serviceItems
                        .map((e) => e.serviceTypeText)
                        .join('、'),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF004D36),
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text('关闭'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF004D36)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A2621),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF5A6B62)),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF8BA49A)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Color(0xFF1A2621)),
            ),
          ),
        ],
      ),
    );
  }
}
