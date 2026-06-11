import 'package:flutter/material.dart';

class CandidateSortOption {
  final String code;
  final String label;

  const CandidateSortOption(this.code, this.label);
}

class CandidateSortBar extends StatelessWidget {
  static const options = [
    CandidateSortOption('distance', '距离最近'),
    CandidateSortOption('rating', '评分最高'),
    CandidateSortOption('totalOrders', '历史总单数'),
  ];

  final String selectedSortBy;
  final ValueChanged<String> onSortChanged;
  final bool isLoading;

  const CandidateSortBar({
    super.key,
    required this.selectedSortBy,
    required this.onSortChanged,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF4F1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final option in options) ...[
            Expanded(
              child: _SortChip(
                label: option.label,
                selected: selectedSortBy == option.code,
                loading: isLoading && selectedSortBy == option.code,
                onTap: isLoading ? null : () => onSortChanged(option.code),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool loading;
  final VoidCallback? onTap;

  const _SortChip({
    required this.label,
    required this.selected,
    required this.loading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          child: loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF004D36),
                  ),
                )
              : Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? const Color(0xFF004D36)
                        : const Color(0xFF5A6B62),
                  ),
                ),
        ),
      ),
    );
  }
}

List<T> sortCandidatesLocally<T>({
  required List<T> candidates,
  required String sortBy,
  required double? Function(T item) distanceKm,
  required double? Function(T item) rating,
  required int Function(T item) totalOrderCount,
}) {
  final sorted = List<T>.from(candidates);
  switch (sortBy) {
    case 'rating':
      sorted.sort((a, b) {
        final ar = rating(a) ?? 0;
        final br = rating(b) ?? 0;
        return br.compareTo(ar);
      });
    case 'totalOrders':
      sorted.sort(
        (a, b) => totalOrderCount(b).compareTo(totalOrderCount(a)),
      );
    case 'distance':
    default:
      sorted.sort((a, b) {
        final ad = distanceKm(a) ?? double.infinity;
        final bd = distanceKm(b) ?? double.infinity;
        return ad.compareTo(bd);
      });
  }
  return sorted;
}
