import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pets/core/network/api_client.dart';

import '../data/datasources/admin_review_appeals_remote_data_source.dart';
import '../data/models/admin_review_appeal_models.dart';

class AdminReviewAppealsScreen extends StatefulWidget {
  const AdminReviewAppealsScreen({super.key});

  @override
  State<AdminReviewAppealsScreen> createState() => _AdminReviewAppealsScreenState();
}

class _AdminReviewAppealsScreenState extends State<AdminReviewAppealsScreen> {
  late final ApiClient _apiClient;
  late final AdminReviewAppealsRemoteDataSource _dataSource;

  bool _isLoading = true;
  String? _error;
  int? _selectedStatus;
  List<AdminReviewAppealItem> _appeals = const [];

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient();
    _dataSource = AdminReviewAppealsRemoteDataSource(_apiClient);
    _loadAppeals();
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  Future<void> _loadAppeals() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final result = await _dataSource.listAppeals(appealStatus: _selectedStatus);
    if (!mounted) return;
    result.when(
      success: (page) {
        setState(() {
          _appeals = page.list;
          _isLoading = false;
        });
      },
      failure: (error) {
        setState(() {
          _error = error.message;
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _openDetail(AdminReviewAppealItem item) async {
    final changed = await context.push<bool>('/admin/review-appeals/${item.appealId}');
    if (changed == true && mounted) {
      _loadAppeals();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F7F4),
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          '申诉处理',
          style: TextStyle(
            color: Color(0xFF1C2B24),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF0C5C43),
        onRefresh: _loadAppeals,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const _AdminSummaryCard(),
            const SizedBox(height: 16),
            _StatusFilterRow(
              selectedStatus: _selectedStatus,
              onChanged: (status) {
                setState(() => _selectedStatus = status);
                _loadAppeals();
              },
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 64),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF0C5C43)),
                ),
              )
            else if (_error != null)
              _StateCard(
                icon: Icons.error_outline,
                title: '申诉列表加载失败',
                message: _error!,
                actionText: '重试',
                onAction: _loadAppeals,
              )
            else if (_appeals.isEmpty)
              const _StateCard(
                icon: Icons.inbox_outlined,
                title: '当前没有申诉单',
                message: '可以稍后回来查看新的低分申诉或仲裁单。',
              )
            else
              ..._appeals.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AppealListCard(item: item, onTap: () => _openDetail(item)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AdminReviewAppealDetailScreen extends StatefulWidget {
  final String appealId;

  const AdminReviewAppealDetailScreen({super.key, required this.appealId});

  @override
  State<AdminReviewAppealDetailScreen> createState() =>
      _AdminReviewAppealDetailScreenState();
}

class _AdminReviewAppealDetailScreenState extends State<AdminReviewAppealDetailScreen> {
  late final ApiClient _apiClient;
  late final AdminReviewAppealsRemoteDataSource _dataSource;
  final TextEditingController _memoController = TextEditingController();

  AdminReviewAppealItem? _appeal;
  AdminOrderEvidenceChain? _evidence;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _didChange = false;
  String? _error;
  int? _selectedStatus;

  int get _appealId => int.tryParse(widget.appealId) ?? 0;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient();
    _dataSource = AdminReviewAppealsRemoteDataSource(_apiClient);
    _loadDetail();
  }

  @override
  void dispose() {
    _memoController.dispose();
    _apiClient.close();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final detailResult = await _dataSource.getAppealDetail(_appealId);
    if (!mounted) return;

    AdminReviewAppealItem? appeal;
    String? error;
    detailResult.when(
      success: (data) => appeal = data,
      failure: (e) => error = e.message,
    );
    if (appeal == null) {
      setState(() {
        _error = error ?? '获取申诉详情失败';
        _isLoading = false;
      });
      return;
    }

    final evidenceResult = await _dataSource.getOrderEvidence(appeal!.orderId);
    if (!mounted) return;

    AdminOrderEvidenceChain? evidence;
    evidenceResult.when(
      success: (data) => evidence = data,
      failure: (_) {},
    );

    _memoController.text = appeal!.adminMemo;
    setState(() {
      _appeal = appeal;
      _evidence = evidence;
      _selectedStatus = appeal!.appealStatus;
      _isLoading = false;
    });
  }

  Future<void> _saveDecision() async {
    final appeal = _appeal;
    final selectedStatus = _selectedStatus;
    if (appeal == null || selectedStatus == null || _isSaving) return;

    setState(() => _isSaving = true);
    final result = await _dataSource.updateAppealStatus(
      appealId: appeal.appealId,
      appealStatus: selectedStatus,
      adminMemo: _memoController.text.trim(),
    );
    if (!mounted) return;

    setState(() => _isSaving = false);
    result.when(
      success: (_) async {
        _didChange = true;
        _showSnackBar('申诉处理结果已保存');
        await _loadDetail();
      },
      failure: (error) {
        _showSnackBar(error.message, isError: true);
      },
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? const Color(0xFFD14B4B) : null,
        ),
      );
  }

  void _handleBack() {
    context.pop(_didChange);
  }

  @override
  Widget build(BuildContext context) {
    final appeal = _appeal;
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7F4),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF6F7F4),
          surfaceTintColor: Colors.transparent,
          title: const Text(
            '申诉详情',
            style: TextStyle(
              color: Color(0xFF1C2B24),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          leading: IconButton(
            onPressed: _handleBack,
            icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF516158)),
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF0C5C43)),
              )
            : _error != null || appeal == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _StateCard(
                    icon: Icons.error_outline,
                    title: '申诉详情加载失败',
                    message: _error ?? '未知错误',
                    actionText: '重试',
                    onAction: _loadDetail,
                  ),
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      color: const Color(0xFF0C5C43),
                      onRefresh: _loadDetail,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        children: [
                          _AppealOverviewCard(appeal: appeal),
                          const SizedBox(height: 12),
                          _AppealReasonCard(appeal: appeal),
                          const SizedBox(height: 12),
                          if (appeal.evidenceUrls.isNotEmpty)
                            _AttachmentSection(
                              title: '申诉附件',
                              imageUrls: appeal.evidenceUrls,
                            ),
                          if (appeal.evidenceUrls.isNotEmpty) const SizedBox(height: 12),
                          _DisputeNodeCard(evidence: _evidence),
                          const SizedBox(height: 12),
                          _EvidenceTimelineCard(evidence: _evidence),
                          const SizedBox(height: 12),
                          _OfficialMessagesCard(evidence: _evidence),
                          const SizedBox(height: 12),
                          _AdminDecisionCard(
                            appeal: appeal,
                            selectedStatus: _selectedStatus,
                            memoController: _memoController,
                            onChanged: (value) => setState(() => _selectedStatus = value),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: _isSaving ? null : _saveDecision,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0C5C43),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                '保存处理结果',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _AdminSummaryCard extends StatelessWidget {
  const _AdminSummaryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF143B30), Color(0xFF1E5B49)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '人工仲裁台',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '集中查看低分申诉、履约证据链与平台备注，按单推进取证、判定和结案。',
            style: TextStyle(
              color: Color(0xFFD7E7E0),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusFilterRow extends StatelessWidget {
  final int? selectedStatus;
  final ValueChanged<int?> onChanged;

  const _StatusFilterRow({
    required this.selectedStatus,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const options = <({int? code, String label})>[
      (code: null, label: '全部'),
      (code: 1, label: '待仲裁'),
      (code: 2, label: '取证中'),
      (code: 3, label: '已判定'),
      (code: 4, label: '申诉成立'),
      (code: 5, label: '申诉失败'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final selected = selectedStatus == option.code;
        return ChoiceChip(
          selected: selected,
          label: Text(option.label),
          labelStyle: TextStyle(
            color: selected ? const Color(0xFF0C5C43) : const Color(0xFF5D6E65),
            fontWeight: FontWeight.w600,
          ),
          backgroundColor: Colors.white,
          selectedColor: const Color(0xFFDCEFE7),
          side: BorderSide(
            color: selected ? const Color(0xFF0C5C43) : const Color(0xFFE1E6E2),
          ),
          onSelected: (_) => onChanged(option.code),
        );
      }).toList(),
    );
  }
}

class _AppealListCard extends StatelessWidget {
  final AdminReviewAppealItem item;
  final VoidCallback onTap;

  const _AppealListCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E8E5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '申诉 #${item.appealId}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C2B24),
                    ),
                  ),
                ),
                _StatusPill(status: item.appealStatus, label: item.appealStatusDesc),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '订单 #${item.orderId} · 宠托师 ${item.providerId} · 宠主 ${item.ownerId}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF7A8B82)),
            ),
            const SizedBox(height: 10),
            Text(
              item.reason.isEmpty ? '申诉人未填写说明' : item.reason,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF33443C),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _TinyBadge(
                  icon: Icons.photo_library_outlined,
                  text: '${item.evidenceUrls.length} 份附件',
                ),
                const SizedBox(width: 8),
                if (item.adminMemo.isNotEmpty)
                  const _TinyBadge(
                    icon: Icons.sticky_note_2_outlined,
                    text: '有平台备注',
                  ),
                const Spacer(),
                Text(
                  _formatDateTime(item.createdAt),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A39B)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AppealOverviewCard extends StatelessWidget {
  final AdminReviewAppealItem appeal;

  const _AppealOverviewCard({required this.appeal});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '申诉 #${appeal.appealId}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C2B24),
                  ),
                ),
              ),
              _StatusPill(status: appeal.appealStatus, label: appeal.appealStatusDesc),
            ],
          ),
          const SizedBox(height: 14),
          _DetailRow(label: '订单号', value: '#${appeal.orderId}'),
          _DetailRow(label: '评价号', value: '#${appeal.reviewId}'),
          _DetailRow(label: '宠托师', value: '${appeal.providerId}'),
          _DetailRow(label: '宠主', value: '${appeal.ownerId}'),
          _DetailRow(label: '提交时间', value: _formatDateTime(appeal.createdAt)),
          if (appeal.appealDeadline.isNotEmpty)
            _DetailRow(label: '申诉时限', value: _formatDateTime(appeal.appealDeadline)),
          if (appeal.closedAt.isNotEmpty)
            _DetailRow(label: '结案时间', value: _formatDateTime(appeal.closedAt)),
        ],
      ),
    );
  }
}

class _AppealReasonCard extends StatelessWidget {
  final AdminReviewAppealItem appeal;

  const _AppealReasonCard({required this.appeal});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('申诉说明'),
          const SizedBox(height: 8),
          Text(
            appeal.reason.isEmpty ? '申诉人未填写说明' : appeal.reason,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF33443C),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _DisputeNodeCard extends StatelessWidget {
  final AdminOrderEvidenceChain? evidence;

  const _DisputeNodeCard({required this.evidence});

  @override
  Widget build(BuildContext context) {
    final records = evidence?.fulfillmentRecords ?? const <AdminFulfillmentRecord>[];
    final order = evidence?.order;
    final disputeNode = records.isEmpty ? null : records.first;
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('争议节点'),
          const SizedBox(height: 10),
          if (order != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '订单当前状态：${order.statusDesc.isEmpty ? order.status : order.statusDesc}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF52635A)),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            disputeNode == null
                ? '暂未查询到履约节点记录，建议先补充人工调查说明。'
                : '优先关注“${disputeNode.nodeTypeDesc.isEmpty ? disputeNode.nodeType : disputeNode.nodeTypeDesc}”节点，结合打卡时间、照片/视频和系统消息进行判责。',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF52635A),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidenceTimelineCard extends StatelessWidget {
  final AdminOrderEvidenceChain? evidence;

  const _EvidenceTimelineCard({required this.evidence});

  @override
  Widget build(BuildContext context) {
    final records = evidence?.fulfillmentRecords ?? const <AdminFulfillmentRecord>[];
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('履约证据链'),
          const SizedBox(height: 10),
          if (records.isEmpty)
            const Text(
              '暂无履约证据记录',
              style: TextStyle(fontSize: 13, color: Color(0xFF7A8B82)),
            )
          else
            ...records.map(
              (record) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _EvidenceRecordTile(record: record),
              ),
            ),
        ],
      ),
    );
  }
}

class _OfficialMessagesCard extends StatelessWidget {
  final AdminOrderEvidenceChain? evidence;

  const _OfficialMessagesCard({required this.evidence});

  @override
  Widget build(BuildContext context) {
    final messages = evidence?.officialMessages ?? const <AdminOfficialMessage>[];
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('系统消息归档'),
          const SizedBox(height: 10),
          if (messages.isEmpty)
            const Text(
              '当前订单没有归档到系统消息',
              style: TextStyle(fontSize: 13, color: Color(0xFF7A8B82)),
            )
          else
            ...messages.map(
              (message) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9F8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDateTime(message.createdAt),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A39B)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      message.content.isEmpty ? '空消息' : message.content,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF33443C),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AdminDecisionCard extends StatelessWidget {
  final AdminReviewAppealItem appeal;
  final int? selectedStatus;
  final TextEditingController memoController;
  final ValueChanged<int?> onChanged;

  const _AdminDecisionCard({
    required this.appeal,
    required this.selectedStatus,
    required this.memoController,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const statusOptions = <DropdownMenuItem<int>>[
      DropdownMenuItem(value: 1, child: Text('待仲裁')),
      DropdownMenuItem(value: 2, child: Text('取证中')),
      DropdownMenuItem(value: 3, child: Text('已判定')),
      DropdownMenuItem(value: 4, child: Text('申诉成立')),
      DropdownMenuItem(value: 5, child: Text('申诉失败')),
    ];
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('人工处理结果'),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey(selectedStatus),
            initialValue: selectedStatus,
            items: statusOptions,
            onChanged: onChanged,
            decoration: InputDecoration(
              labelText: '处理状态',
              filled: true,
              fillColor: const Color(0xFFF7F9F8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: memoController,
            maxLines: 6,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: '平台处理备注',
              hintText: '例如：核对门禁记录与到场照片后，确认延迟原因为小区门禁故障，本次申诉成立，不做赔付扣款。',
              filled: true,
              fillColor: const Color(0xFFF7F9F8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (appeal.adminMemo.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '当前备注：${appeal.adminMemo}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF7A8B82)),
              ),
            ),
        ],
      ),
    );
  }
}

class _AttachmentSection extends StatelessWidget {
  final String title;
  final List<String> imageUrls;

  const _AttachmentSection({required this.title, required this.imageUrls});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('$title (${imageUrls.length})'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: imageUrls.map((url) => _NetworkThumb(url: url)).toList(),
          ),
        ],
      ),
    );
  }
}

class _EvidenceRecordTile extends StatelessWidget {
  final AdminFulfillmentRecord record;

  const _EvidenceRecordTile({required this.record});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  record.nodeTypeDesc.isEmpty ? '节点 ${record.nodeType}' : record.nodeTypeDesc,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C2B24),
                  ),
                ),
              ),
              Text(
                _formatDateTime(record.createdAt),
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A39B)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (record.hasMedia)
            record.isVideo
                ? Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      color: const Color(0xFF21362E),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.play_circle_outline,
                      color: Colors.white70,
                      size: 34,
                    ),
                  )
                : _NetworkThumb(url: record.url),
          if (record.watermarkText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '水印：${record.watermarkText}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF52635A)),
            ),
          ],
          if (record.processingError.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '处理异常：${record.processingError}',
              style: const TextStyle(fontSize: 12, color: Color(0xFFD14B4B)),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E8E5)),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1C2B24),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final int status;
  final String label;

  const _StatusPill({required this.status, required this.label});

  @override
  Widget build(BuildContext context) {
    final foreground = switch (status) {
      4 => const Color(0xFF0C5C43),
      5 => const Color(0xFFD14B4B),
      _ => const Color(0xFFE48A12),
    };
    final background = switch (status) {
      4 => const Color(0xFFE2F1EA),
      5 => const Color(0xFFFFF1EF),
      _ => const Color(0xFFFFF7EA),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.isEmpty ? '处理中' : label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

class _TinyBadge extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TinyBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F5F3),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF6F8078)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6F8078)),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A39B)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Color(0xFF33443C)),
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkThumb extends StatelessWidget {
  final String url;

  const _NetworkThumb({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url,
        width: 96,
        height: 96,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 96,
          height: 96,
          color: const Color(0xFFF0F5F3),
          child: const Icon(Icons.broken_image_outlined),
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionText;
  final VoidCallback? onAction;

  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E8E5)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: const Color(0xFF8FA198)),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C2B24),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6F8078),
              height: 1.5,
            ),
          ),
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onAction, child: Text(actionText!)),
          ],
        ],
      ),
    );
  }
}

String _formatDateTime(String value) {
  if (value.isEmpty) return '--';
  return value.replaceFirst('T', ' ');
}
