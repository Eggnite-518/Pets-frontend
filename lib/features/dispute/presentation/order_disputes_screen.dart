import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:pets/core/network/api_client.dart';
import 'package:pets/core/network/api_exception.dart';
import 'package:pets/features/caretaker/data/datasources/upload_remote_data_source.dart';

import '../data/datasources/order_dispute_remote_data_source.dart';
import '../data/models/order_dispute_models.dart';

class OrderDisputesScreen extends StatefulWidget {
  final String orderId;
  final bool isCaretaker;

  const OrderDisputesScreen({
    super.key,
    required this.orderId,
    required this.isCaretaker,
  });

  @override
  State<OrderDisputesScreen> createState() => _OrderDisputesScreenState();
}

class _OrderDisputesScreenState extends State<OrderDisputesScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _reasonController = TextEditingController();
  final List<_DisputeEvidenceDraft> _draftEvidence = [];

  late final ApiClient _apiClient;
  late final OrderDisputeRemoteDataSource _dataSource;
  late final http.Client _uploadHttpClient;
  late final UploadRemoteDataSource _uploadDataSource;

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isUploading = false;
  bool _canSubmit = false;
  String? _error;
  int _selectedDisputeType = 1;
  List<OrderDisputeItem> _disputes = const [];
  OrderEvidenceChain? _evidence;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient();
    _dataSource = OrderDisputeRemoteDataSource(_apiClient);
    _uploadHttpClient = http.Client();
    _uploadDataSource = UploadRemoteDataSource(_uploadHttpClient);
    _loadData();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _uploadHttpClient.close();
    _apiClient.close();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _canSubmit = false;
    });
    final disputesResult = await _dataSource.listDisputes(widget.orderId);
    if (!mounted) return;

    final evidenceResult = await _dataSource.getEvidence(widget.orderId);
    if (!mounted) return;

    disputesResult.when(
      success: (items) {
        _disputes = items;
        _canSubmit = true;
      },
      failure: (error) {
        _error = error.message;
        _canSubmit = false;
      },
    );
    evidenceResult.when(
      success: (evidence) => _evidence = evidence,
      failure: (_) {},
    );
    setState(() => _isLoading = false);
  }

  Future<void> _showEvidencePicker() async {
    if (_isUploading || _draftEvidence.length >= 6) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('拍照上传'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    await _pickAndUploadEvidence(source);
  }

  Future<void> _pickAndUploadEvidence(ImageSource source) async {
    final picked = await _imagePicker.pickImage(source: source, imageQuality: 85);
    if (picked == null || !mounted) return;

    setState(() => _isUploading = true);
    try {
      final url = await _uploadDataSource.uploadImage(File(picked.path));
      if (!mounted) return;
      setState(() {
        _draftEvidence.add(_DisputeEvidenceDraft(localPath: picked.path, url: url));
      });
    } on ApiException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar('证据上传失败', isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _submitDispute() async {
    if (_isSubmitting || _isUploading) return;
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      _showSnackBar('请填写申诉说明', isError: true);
      return;
    }
    setState(() => _isSubmitting = true);
    final result = await _dataSource.submitDispute(
      orderId: widget.orderId,
      disputeType: _selectedDisputeType,
      reason: reason,
      evidenceUrls: _draftEvidence.map((item) => item.url).toList(),
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    result.when(
      success: (_) async {
        _showSnackBar('申诉已提交，平台会尽快介入');
        _reasonController.clear();
        _draftEvidence.clear();
        await _loadData();
      },
      failure: (error) => _showSnackBar(error.message, isError: true),
    );
  }

  void _removeEvidence(_DisputeEvidenceDraft item) {
    setState(() => _draftEvidence.remove(item));
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

  @override
  Widget build(BuildContext context) {
    final latest = _disputes.isEmpty ? null : _disputes.first;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F7F4),
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          '申诉与仲裁',
          style: TextStyle(
            color: Color(0xFF1C2B24),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF52635A)),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF0C5C43),
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _GuideCard(isCaretaker: widget.isCaretaker),
            const SizedBox(height: 12),
            if (latest != null) ...[
              _LatestStatusCard(dispute: latest),
              const SizedBox(height: 12),
            ],
            if (!_isLoading && !_canSubmit)
              const _StateCard(
                icon: Icons.lock_outline,
                title: '暂不可申诉',
                message: '订单支付完成、双方正式成单后才可发起申诉与仲裁。',
              )
            else ...[
              _ComposerCard(
                selectedType: _selectedDisputeType,
                onTypeChanged: (value) => setState(() => _selectedDisputeType = value),
                controller: _reasonController,
                evidence: _draftEvidence,
                isUploading: _isUploading,
                onAddEvidence: _showEvidencePicker,
                onRemoveEvidence: _removeEvidence,
              ),
              const SizedBox(height: 12),
            ],
            _EvidenceCard(evidence: _evidence),
            const SizedBox(height: 12),
            _MessagesCard(evidence: _evidence),
            const SizedBox(height: 12),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF0C5C43)),
                ),
              )
            else if (_error != null)
              _StateCard(
                icon: Icons.error_outline,
                title: '申诉记录加载失败',
                message: _error!,
                actionText: '重试',
                onAction: _loadData,
              )
            else if (_disputes.isEmpty && _canSubmit)
              const _StateCard(
                icon: Icons.inbox_outlined,
                title: '还没有申诉记录',
                message: '如果你对系统判责、服务过程或赔付结果有异议，可以直接在上方提交说明。',
              )
            else
              ..._disputes.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DisputeHistoryCard(dispute: item),
                ),
              ),
            const SizedBox(height: 88),
          ],
        ),
      ),
      bottomSheet: _canSubmit
          ? Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submitDispute,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0C5C43),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          '提交申诉',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            )
          : null,
    );
  }
}

class _GuideCard extends StatelessWidget {
  final bool isCaretaker;

  const _GuideCard({required this.isCaretaker});

  @override
  Widget build(BuildContext context) {
    final title = isCaretaker ? '服务者申诉入口' : '宠主申诉入口';
    final desc = isCaretaker
        ? '对系统判责、履约异常认定或扣款结果有异议时，可在此补充说明和证据，等待平台人工复核。'
        : '对服务过程、系统判责或赔付结果有异议时，可在此提交申诉，平台会结合证据链给出结论。';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF173A31), Color(0xFF245546)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: const TextStyle(
              color: Color(0xFFD6E6DF),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _LatestStatusCard extends StatelessWidget {
  final OrderDisputeItem dispute;

  const _LatestStatusCard({required this.dispute});

  @override
  Widget build(BuildContext context) {
    final resultText = dispute.resultTypeDesc.isNotEmpty
        ? '当前结论：${dispute.resultTypeDesc}'
        : dispute.isClosed
        ? '平台已给出最终处理结果，请查看下方详情。'
        : '平台正在处理当前申诉，请留意后续仲裁结论。';
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '最新处理进度',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C2B24),
                  ),
                ),
              ),
              _StatusPill(dispute: dispute),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            resultText,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF52635A),
              height: 1.5,
            ),
          ),
          if (dispute.adminMemo.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                dispute.adminMemo,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF33443C),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ComposerCard extends StatelessWidget {
  final int selectedType;
  final ValueChanged<int> onTypeChanged;
  final TextEditingController controller;
  final List<_DisputeEvidenceDraft> evidence;
  final bool isUploading;
  final VoidCallback onAddEvidence;
  final ValueChanged<_DisputeEvidenceDraft> onRemoveEvidence;

  const _ComposerCard({
    required this.selectedType,
    required this.onTypeChanged,
    required this.controller,
    required this.evidence,
    required this.isUploading,
    required this.onAddEvidence,
    required this.onRemoveEvidence,
  });

  @override
  Widget build(BuildContext context) {
    const items = <DropdownMenuItem<int>>[
      DropdownMenuItem(value: 1, child: Text('履约打卡异常')),
      DropdownMenuItem(value: 2, child: Text('服务质量争议')),
      DropdownMenuItem(value: 3, child: Text('宠物/财物受损')),
      DropdownMenuItem(value: 4, child: Text('费用与赔付争议')),
      DropdownMenuItem(value: 5, child: Text('其他严重违规')),
    ];
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '提交申诉说明',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C2B24),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: selectedType,
            key: ValueKey(selectedType),
            items: items,
            onChanged: (value) {
              if (value != null) onTypeChanged(value);
            },
            decoration: InputDecoration(
              labelText: '争议类型',
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
            controller: controller,
            maxLines: 5,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: '请写明争议节点，例如未能按时上传打卡、异常扣款原因、宠物状态变化等，平台会结合证据链人工判定。',
              filled: true,
              fillColor: const Color(0xFFF7F9F8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          Row(
            children: [
              const Text(
                '补充证据',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1C2B24),
                ),
              ),
              const Spacer(),
              Text(
                '${evidence.length}/6',
                style: const TextStyle(fontSize: 12, color: Color(0xFF8FA198)),
              ),
            ],
          ),
          if (evidence.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemBuilder: (_, index) => _LocalEvidenceThumb(
                  item: evidence[index],
                  onRemove: () => onRemoveEvidence(evidence[index]),
                ),
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemCount: evidence.length,
              ),
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: isUploading || evidence.length >= 6 ? null : onAddEvidence,
            icon: isUploading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_photo_alternate_outlined),
            label: Text(isUploading ? '上传中' : '添加证据图片'),
          ),
        ],
      ),
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  final OrderEvidenceChain? evidence;

  const _EvidenceCard({required this.evidence});

  @override
  Widget build(BuildContext context) {
    final records = evidence?.fulfillmentRecords ?? const <OrderFulfillmentRecord>[];
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '争议节点与履约证据',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C2B24),
            ),
          ),
          const SizedBox(height: 10),
          if (records.isEmpty)
            const Text(
              '平台暂未归档到履约节点，可先提交说明，人工客服会进一步调证。',
              style: TextStyle(fontSize: 13, color: Color(0xFF52635A), height: 1.5),
            )
          else
            ...records.map(
              (record) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _EvidenceRecordTile(record: record),
              ),
            ),
        ],
      ),
    );
  }
}

class _MessagesCard extends StatelessWidget {
  final OrderEvidenceChain? evidence;

  const _MessagesCard({required this.evidence});

  @override
  Widget build(BuildContext context) {
    final messages = evidence?.officialMessages ?? const <OrderOfficialMessage>[];
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '系统归档消息',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C2B24),
            ),
          ),
          const SizedBox(height: 10),
          if (messages.isEmpty)
            const Text(
              '暂无系统归档消息',
              style: TextStyle(fontSize: 13, color: Color(0xFF52635A)),
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
                      style: const TextStyle(fontSize: 11, color: Color(0xFF8FA198)),
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

class _DisputeHistoryCard extends StatelessWidget {
  final OrderDisputeItem dispute;

  const _DisputeHistoryCard({required this.dispute});

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
                  dispute.disputeTypeDesc.isEmpty ? '申诉 #${dispute.disputeId}' : dispute.disputeTypeDesc,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C2B24),
                  ),
                ),
              ),
              _StatusPill(dispute: dispute),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '提交时间 ${_formatDateTime(dispute.createdAt)}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF8FA198)),
          ),
          const SizedBox(height: 10),
          Text(
            dispute.reason.isEmpty ? '未填写说明' : dispute.reason,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF33443C),
              height: 1.55,
            ),
          ),
          if (dispute.evidenceUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: dispute.evidenceUrls.map((url) => _NetworkThumb(url: url)).toList(),
            ),
          ],
          if (dispute.resultTypeDesc.isNotEmpty || dispute.adminMemo.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (dispute.resultTypeDesc.isNotEmpty)
                    Text(
                      '处理结论：${dispute.resultTypeDesc}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1C2B24),
                      ),
                    ),
                  if (dispute.adminMemo.isNotEmpty) ...[
                    if (dispute.resultTypeDesc.isNotEmpty) const SizedBox(height: 6),
                    Text(
                      dispute.adminMemo,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF52635A),
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EvidenceRecordTile extends StatelessWidget {
  final OrderFulfillmentRecord record;

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
                style: const TextStyle(fontSize: 11, color: Color(0xFF8FA198)),
              ),
            ],
          ),
          if (record.hasMedia) ...[
            const SizedBox(height: 8),
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
          ],
          if (record.watermarkText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '水印：${record.watermarkText}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF52635A)),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final OrderDisputeItem dispute;

  const _StatusPill({required this.dispute});

  @override
  Widget build(BuildContext context) {
    final closed = dispute.isClosed;
    final foreground = closed
        ? const Color(0xFF0C5C43)
        : dispute.disputeStatus == 1
        ? const Color(0xFFE48A12)
        : const Color(0xFF246BCE);
    final background = closed
        ? const Color(0xFFE3F1EA)
        : dispute.disputeStatus == 1
        ? const Color(0xFFFFF7EA)
        : const Color(0xFFEAF2FF);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        dispute.disputeStatusDesc.isEmpty ? '处理中' : dispute.disputeStatusDesc,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
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
    return _SectionCard(
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

class _LocalEvidenceThumb extends StatelessWidget {
  final _DisputeEvidenceDraft item;
  final VoidCallback onRemove;

  const _LocalEvidenceThumb({required this.item, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: const Color(0xFFF4F7F6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8E5)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.file(File(item.localPath), fit: BoxFit.cover),
        ),
        Positioned(
          top: -8,
          right: -8,
          child: IconButton.filledTonal(
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            padding: EdgeInsets.zero,
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 16),
          ),
        ),
      ],
    );
  }
}

class _DisputeEvidenceDraft {
  final String localPath;
  final String url;

  const _DisputeEvidenceDraft({required this.localPath, required this.url});
}

String _formatDateTime(String value) {
  if (value.isEmpty) return '--';
  return value.replaceFirst('T', ' ');
}
