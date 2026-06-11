import 'package:flutter/material.dart';
import 'package:pets/core/network/api_client.dart';

import '../data/datasources/caretaker_profile_remote_data_source.dart';
import '../data/repositories/caretaker_profile_repository_impl.dart';
import '../domain/entities/caretaker_income_record.dart';
import '../domain/entities/caretaker_wallet.dart';
import '../domain/usecases/get_caretaker_wallet_use_case.dart';
import '../domain/usecases/get_income_records_use_case.dart';

class CaretakerIncomeScreen extends StatefulWidget {
  const CaretakerIncomeScreen({super.key});

  @override
  State<CaretakerIncomeScreen> createState() => _CaretakerIncomeScreenState();
}

class _CaretakerIncomeScreenState extends State<CaretakerIncomeScreen> {
  late final GetCaretakerWalletUseCase _getWalletUseCase;
  late final GetIncomeRecordsUseCase _getIncomeRecordsUseCase;
  final ScrollController _scrollController = ScrollController();

  CaretakerWallet? _wallet;
  List<CaretakerIncomeRecord> _records = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  static const int _pageSize = 20;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final client = ApiClient();
    final dataSource = CaretakerProfileRemoteDataSource(client);
    final repo = CaretakerProfileRepositoryImpl(dataSource);
    _getWalletUseCase = GetCaretakerWalletUseCase(repo);
    _getIncomeRecordsUseCase = GetIncomeRecordsUseCase(repo);
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
            _scrollController.position.maxScrollExtent - 100 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _records = [];
      _currentPage = 1;
      _hasMore = true;
    });

    await Future.wait([
      _loadWallet(),
      _loadRecords(page: 1),
    ]);
  }

  Future<void> _loadWallet() async {
    final result = await _getWalletUseCase();
    if (!mounted) return;
    result.when(
      success: (wallet) => setState(() => _wallet = wallet),
      failure: (_) {},
    );
  }

  Future<void> _loadRecords({required int page}) async {
    final result = await _getIncomeRecordsUseCase(page: page, pageSize: _pageSize);
    if (!mounted) return;
    result.when(
      success: (data) => setState(() {
        if (page == 1) {
          _records = data.list;
        } else {
          _records = [..._records, ...data.list];
        }
        _currentPage = data.page;
        _hasMore = _records.length < data.total;
        _isLoading = false;
        _isLoadingMore = false;
      }),
      failure: (error) => setState(() {
        _errorMessage = error.message;
        _isLoading = false;
        _isLoadingMore = false;
      }),
    );
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    await _loadRecords(page: _currentPage + 1);
  }

  Widget _buildLoadMoreFooter() {
    if (_isLoading) return const SizedBox.shrink();
    if (_isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF004D36),
            strokeWidth: 2,
          ),
        ),
      );
    }
    if (!_hasMore && _records.isNotEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            '— 已加载全部记录 —',
            style: TextStyle(fontSize: 13, color: Color(0xFFC3D5CC)),
          ),
        ),
      );
    }
    return const SizedBox(height: 24);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9F8),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A2621)),
        title: const Text(
          '收入明细',
          style: TextStyle(
            color: Color(0xFF1A2621),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF004D36),
        onRefresh: _loadAll,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _WalletSummaryCard(wallet: _wallet),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF004D36),
                  ),
                ),
              )
            else if (_errorMessage != null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _errorMessage!,
                        style:
                            const TextStyle(color: Color(0xFF8BA49A)),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _loadAll,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_records.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Text(
                    '暂无收支记录',
                    style:
                        TextStyle(fontSize: 15, color: Color(0xFF8BA49A)),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, index) => _IncomeRecordItem(
                      record: _records[index],
                      showDivider: index < _records.length - 1,
                    ),
                    childCount: _records.length,
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: _buildLoadMoreFooter(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 余额汇总卡片 ─────────────────────────────────────────────────────────────

class _WalletSummaryCard extends StatelessWidget {
  final CaretakerWallet? wallet;

  const _WalletSummaryCard({this.wallet});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF004D36),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33004D36),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '可提现余额',
              style: TextStyle(color: Color(0xFFC3D5CC), fontSize: 13),
            ),
            const SizedBox(height: 6),
            wallet == null
                ? Container(
                    height: 36,
                    width: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFF33705E),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  )
                : Text(
                    '¥${wallet!.balance}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

// ─── 单条流水记录 ─────────────────────────────────────────────────────────────

class _IncomeRecordItem extends StatelessWidget {
  final CaretakerIncomeRecord record;
  final bool showDivider;

  const _IncomeRecordItem({
    required this.record,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = record.isIncome;
    final amountText =
        isIncome ? '+¥${record.amount}' : '-¥${record.amount}';
    final amountColor =
        isIncome ? const Color(0xFF004D36) : const Color(0xFFF06A42);

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isIncome
                        ? const Color(0xFFE8F2EF)
                        : const Color(0xFFFFF3F0),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    isIncome
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    size: 20,
                    color: isIncome
                        ? const Color(0xFF004D36)
                        : const Color(0xFFF06A42),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.typeText.isNotEmpty
                            ? record.typeText
                            : (isIncome ? '收入' : '支出'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A2621),
                        ),
                      ),
                      if (record.description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          record.description,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF8BA49A),
                          ),
                        ),
                      ],
                      if (record.createdAt.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(record.createdAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFC3D5CC),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  amountText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: amountColor,
                  ),
                ),
              ],
            ),
          ),
          if (showDivider)
            const Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFF7F9F8),
              indent: 68,
            ),
        ],
      ),
    );
  }

  String _formatDate(String raw) {
    if (raw.length >= 10) return raw.substring(0, 10);
    return raw;
  }
}
