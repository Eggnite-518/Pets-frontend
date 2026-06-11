import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pets/core/network/api_client.dart';

import '../data/datasources/caretaker_reviews_remote_data_source.dart';
import '../data/models/caretaker_review_models.dart';

enum _ReviewFilter { all, lowScore, appealing }

class CaretakerReviewsScreen extends StatefulWidget {
  const CaretakerReviewsScreen({super.key});

  @override
  State<CaretakerReviewsScreen> createState() => _CaretakerReviewsScreenState();
}

class _CaretakerReviewsScreenState extends State<CaretakerReviewsScreen> {
  late final CaretakerReviewsRemoteDataSource _ds;
  final ScrollController _scrollController = ScrollController();

  CaretakerReviewStats? _stats;
  final List<CaretakerReviewItem> _reviews = [];
  _ReviewFilter _filter = _ReviewFilter.all;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _error;

  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _ds = CaretakerReviewsRemoteDataSource(ApiClient());
    _scrollController.addListener(_onScroll);
    _loadAll();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 120 &&
        !_isLoadingMore &&
        _hasMore &&
        !_isLoading) {
      _loadMore();
    }
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _reviews.clear();
      _currentPage = 1;
      _hasMore = true;
    });

    final statsResult = await _ds.getStats();
    if (!mounted) return;
    statsResult.when(
      success: (stats) => setState(() => _stats = stats),
      failure: (_) {},
    );

    await _loadPage(1);
  }

  Future<void> _loadPage(int page) async {
    final result = await _ds.listReviews(
      page: page,
      pageSize: _pageSize,
      reviewStatus: _filter == _ReviewFilter.appealing ? 2 : null,
      lowScoreOnly: _filter == _ReviewFilter.lowScore ? true : null,
    );
    if (!mounted) return;

    result.when(
      success: (data) {
        setState(() {
          if (page == 1) {
            _reviews
              ..clear()
              ..addAll(data.list);
          } else {
            _reviews.addAll(data.list);
          }
          _currentPage = data.page;
          _hasMore = _reviews.length < data.total;
          _isLoading = false;
          _isLoadingMore = false;
        });
      },
      failure: (e) => setState(() {
        _error = e.message;
        _isLoading = false;
        _isLoadingMore = false;
      }),
    );
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    await _loadPage(_currentPage + 1);
  }

  void _changeFilter(_ReviewFilter filter) {
    if (_filter == filter) return;
    setState(() => _filter = filter);
    _loadAll();
  }

  void _openDetail(CaretakerReviewItem item) async {
    final changed = await context.push<bool>(
      '/caretaker/reviews/${item.reviewId}',
      extra: item,
    );
    if (changed == true && mounted) {
      _loadAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9F8),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '我的评价',
          style: TextStyle(
            color: Color(0xFF1A2621),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFF5A6B62),
            size: 20,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/caretaker/profile');
            }
          },
        ),
      ),
      body: _isLoading && _reviews.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF004D36)),
            )
          : _error != null && _reviews.isEmpty
          ? _ErrorView(message: _error!, onRetry: _loadAll)
          : RefreshIndicator(
              color: const Color(0xFF004D36),
              onRefresh: _loadAll,
              child: ListView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (_stats != null) _StatsCard(stats: _stats!),
                  const SizedBox(height: 16),
                  _FilterBar(current: _filter, onChanged: _changeFilter),
                  const SizedBox(height: 12),
                  if (_reviews.isEmpty)
                    const _EmptyReviews()
                  else
                    ..._reviews.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ReviewTile(
                          item: item,
                          onTap: () => _openDetail(item),
                        ),
                      ),
                    ),
                  if (_isLoadingMore)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF004D36),
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final CaretakerReviewStats stats;

  const _StatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final lowRatePercent = (stats.lowScoreRate * 100).toStringAsFixed(1);
    return Container(
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F2EF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: Color(0xFF004D36),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stats.overallAvg.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF004D36),
                    ),
                  ),
                  Text(
                    '综合评分 · 共 ${stats.reviewCount} 条',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8BA49A),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  label: '准时度',
                  value: stats.punctualityAvg.toStringAsFixed(1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatChip(
                  label: '专业度',
                  value: stats.professionalAvg.toStringAsFixed(1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatChip(label: '低分率', value: '$lowRatePercent%'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatChip(
                  label: '近30天',
                  value: '${stats.recent30DayReviewCount} 条',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF8BA49A)),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A2621),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final _ReviewFilter current;
  final ValueChanged<_ReviewFilter> onChanged;

  const _FilterBar({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FilterChip(
          label: '全部',
          selected: current == _ReviewFilter.all,
          onTap: () => onChanged(_ReviewFilter.all),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: '低分',
          selected: current == _ReviewFilter.lowScore,
          onTap: () => onChanged(_ReviewFilter.lowScore),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: '申诉中',
          selected: current == _ReviewFilter.appealing,
          onTap: () => onChanged(_ReviewFilter.appealing),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF004D36) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF004D36) : const Color(0xFFEBEBEB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF5A6B62),
          ),
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final CaretakerReviewItem item;
  final VoidCallback onTap;

  const _ReviewTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final petNames = item.pets.map((p) => p.petName).where((n) => n.isNotEmpty);
    final petLabel = petNames.isEmpty ? '服务订单' : petNames.join('、');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: item.isLowScore
                  ? const Color(0xFFF0C4BC)
                  : const Color(0xFFEBEBEB),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _ScoreBadge(score: item.overallScore),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          petLabel,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A2621),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatMeta(item),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8BA49A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusTag(
                    label: item.reviewStatusDesc,
                    status: item.reviewStatus,
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right,
                    color: Color(0xFFB0C4BC),
                    size: 20,
                  ),
                ],
              ),
              if (item.comment.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  item.comment,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF5A6B62),
                    height: 1.45,
                  ),
                ),
              ],
              if (item.deductionReasons.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: item.deductionReasons
                      .map(
                        (r) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3F0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            r.reasonTypeDesc,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFD14B4B),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              if (item.creditDeductionScore > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF6F4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.trending_down_rounded,
                        size: 16,
                        color: Color(0xFFD14B4B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '本次评价信用分 -${item.creditDeductionScore}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFD14B4B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatMeta(CaretakerReviewItem item) {
    final parts = <String>[];
    if (item.serviceDate.isNotEmpty) {
      parts.add(
        item.serviceDate.length >= 10
            ? item.serviceDate.substring(0, 10)
            : item.serviceDate,
      );
    }
    parts.add('准时 ${item.punctualityScore} · 专业 ${item.professionalScore}');
    return parts.join(' · ');
  }
}

class _ScoreBadge extends StatelessWidget {
  final int score;

  const _ScoreBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score <= 3
        ? const Color(0xFFD14B4B)
        : score <= 4
        ? const Color(0xFFE9820A)
        : const Color(0xFF004D36);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        '$score',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  final String label;
  final int status;

  const _StatusTag({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case 2:
        bg = const Color(0xFFFFF8ED);
        fg = const Color(0xFFE9820A);
      case 3:
        bg = const Color(0xFFE8F2EF);
        fg = const Color(0xFF004D36);
      case 4:
        bg = const Color(0xFFFFF3F0);
        fg = const Color(0xFFD14B4B);
      default:
        bg = const Color(0xFFF0F5F3);
        fg = const Color(0xFF5A6B62);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label.isEmpty ? '正常' : label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class _EmptyReviews extends StatelessWidget {
  const _EmptyReviews();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: const [
          Icon(Icons.rate_review_outlined, size: 48, color: Color(0xFFB0C4BC)),
          SizedBox(height: 12),
          Text(
            '暂无符合条件的评价',
            style: TextStyle(fontSize: 14, color: Color(0xFF8BA49A)),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF5A6B62)),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
