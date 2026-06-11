import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:pets/core/network/api_client.dart';
import 'package:pets/core/network/api_exception.dart';

import '../data/datasources/caretaker_reviews_remote_data_source.dart';
import '../data/datasources/upload_remote_data_source.dart';
import '../data/models/caretaker_review_models.dart';

class CaretakerReviewDetailScreen extends StatefulWidget {
  final String reviewId;
  final CaretakerReviewItem? initialReview;

  const CaretakerReviewDetailScreen({
    super.key,
    required this.reviewId,
    this.initialReview,
  });

  @override
  State<CaretakerReviewDetailScreen> createState() =>
      _CaretakerReviewDetailScreenState();
}

class _CaretakerReviewDetailScreenState
    extends State<CaretakerReviewDetailScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _appealReasonController = TextEditingController();
  final List<_AppealEvidenceDraft> _appealEvidence = [];

  late final ApiClient _apiClient;
  late final CaretakerReviewsRemoteDataSource _ds;
  late final http.Client _uploadHttpClient;
  late final UploadRemoteDataSource _uploadDs;

  CaretakerReviewItem? _review;
  ReviewAppealEligibility? _eligibility;
  ReviewAppealDetail? _appeal;
  bool _isLoading = true;
  bool _isLoadingAppeal = false;
  bool _isSubmittingAppeal = false;
  bool _isUploadingEvidence = false;
  bool _didChangeData = false;
  String? _error;

  int get _reviewIdInt => int.tryParse(widget.reviewId) ?? 0;

  bool get _canAppeal =>
      (_review?.canAppeal ?? false) || (_eligibility?.canAppeal ?? false);

  bool get _showAppealComposer => _appeal == null && _canAppeal;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient();
    _ds = CaretakerReviewsRemoteDataSource(_apiClient);
    _uploadHttpClient = http.Client();
    _uploadDs = UploadRemoteDataSource(_uploadHttpClient);
    _review = widget.initialReview;
    _loadDetail();
  }

  @override
  void dispose() {
    _appealReasonController.dispose();
    _uploadHttpClient.close();
    _apiClient.close();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = _review == null;
      _isLoadingAppeal = true;
      _error = null;
    });

    final detailResult = await _ds.getReviewDetail(_reviewIdInt);
    if (!mounted) return;

    detailResult.when(
      success: (review) => _review = review,
      failure: (e) {
        if (_review == null) _error = e.message;
      },
    );

    final eligibilityResult = await _ds.getAppealEligibility(_reviewIdInt);
    if (!mounted) return;

    eligibilityResult.when(
      success: (eligibility) => _eligibility = eligibility,
      failure: (_) {},
    );

    final appealResult = await _ds.getLatestAppeal(_reviewIdInt);
    if (!mounted) return;

    appealResult.when(
      success: (appeal) {
        _appeal = appeal;
        if (appeal != null) {
          _appealReasonController.text = appeal.reason;
          _appealEvidence.clear();
        }
      },
      failure: (_) => _appeal = null,
    );

    setState(() {
      _isLoading = false;
      _isLoadingAppeal = false;
    });
  }

  Future<void> _showEvidencePicker() async {
    if (_isUploadingEvidence || _appealEvidence.length >= 6) return;

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
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _isUploadingEvidence = true);
    try {
      final url = await _uploadDs.uploadImage(File(picked.path));
      if (!mounted) return;
      setState(() {
        _appealEvidence.add(
          _AppealEvidenceDraft(localPath: picked.path, url: url),
        );
      });
    } on ApiException catch (e) {
      if (mounted) {
        _showSnackBar(e.message, backgroundColor: const Color(0xFFD14B4B));
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar('证据上传失败', backgroundColor: const Color(0xFFD14B4B));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingEvidence = false);
      }
    }
  }

  Future<void> _submitAppeal() async {
    final review = _review;
    if (review == null || _isSubmittingAppeal || _isUploadingEvidence) return;

    final reason = _appealReasonController.text.trim();
    if (reason.isEmpty) {
      _showSnackBar('请填写申诉理由', backgroundColor: const Color(0xFFD14B4B));
      return;
    }

    setState(() => _isSubmittingAppeal = true);
    final result = await _ds.submitAppeal(
      reviewId: _reviewIdInt,
      reason: reason,
      evidenceUrls: _appealEvidence.map((item) => item.url).toList(),
    );
    if (!mounted) return;

    setState(() => _isSubmittingAppeal = false);
    result.when(
      success: (appeal) async {
        _didChangeData = true;
        _showSnackBar('申诉已提交：${appeal.appealStatusDesc}');
        await _loadDetail();
      },
      failure: (e) {
        _showSnackBar(e.message, backgroundColor: const Color(0xFFD14B4B));
      },
    );
  }

  void _handleBack() {
    context.pop(_didChangeData);
  }

  void _removeEvidence(_AppealEvidenceDraft item) {
    setState(() => _appealEvidence.remove(item));
  }

  void _showSnackBar(String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: backgroundColor),
      );
  }

  @override
  Widget build(BuildContext context) {
    final review = _review;
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9F8),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF7F9F8),
          elevation: 0,
          centerTitle: true,
          title: const Text(
            '评价详情',
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
            onPressed: _handleBack,
          ),
        ),
        body: _isLoading && review == null
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF004D36)),
              )
            : _error != null && review == null
            ? Center(child: Text(_error!))
            : review == null
            ? const SizedBox.shrink()
            : Column(
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      color: const Color(0xFF004D36),
                      onRefresh: _loadDetail,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _HeaderCard(review: review),
                            const SizedBox(height: 12),
                            _ScoreCard(review: review),
                            if (review.deductionReasons.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _ReasonCard(reasons: review.deductionReasons),
                            ],
                            if (review.comment.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _CommentCard(comment: review.comment),
                            ],
                            if (review.attachments.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _AttachmentCard(
                                title: '评价附件',
                                reviewAttachments: review.attachments,
                              ),
                            ],
                            if (_appeal != null || _isLoadingAppeal) ...[
                              const SizedBox(height: 12),
                              _AppealStatusCard(
                                appeal: _appeal,
                                isLoading: _isLoadingAppeal,
                              ),
                            ],
                            if (_showAppealComposer) ...[
                              const SizedBox(height: 12),
                              _AppealComposerCard(
                                controller: _appealReasonController,
                                evidence: _appealEvidence,
                                isUploading: _isUploadingEvidence,
                                onAddEvidence: _showEvidencePicker,
                                onRemoveEvidence: _removeEvidence,
                              ),
                            ],
                            if (_eligibility != null &&
                                !_eligibility!.canAppeal &&
                                _eligibility!.unavailableReason.isNotEmpty &&
                                _appeal == null &&
                                review.reviewStatus != 2) ...[
                              const SizedBox(height: 12),
                              _InfoBanner(
                                text: _eligibility!.unavailableReason,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_showAppealComposer)
                    _AppealBar(
                      isSubmitting: _isSubmittingAppeal || _isUploadingEvidence,
                      deadline: review.appealDeadline.isNotEmpty
                          ? review.appealDeadline
                          : _eligibility?.appealDeadline ?? '',
                      buttonText: _isUploadingEvidence ? '上传中' : '提交申诉',
                      onPressed: _submitAppeal,
                    ),
                ],
              ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final CaretakerReviewItem review;

  const _HeaderCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final pets = review.pets
        .map(
          (p) =>
              '${p.petName}${p.petTypeDesc.isNotEmpty ? '（${p.petTypeDesc}）' : ''}',
        )
        .join('、');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEBEBEB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  pets.isEmpty ? '服务订单 #${review.orderId}' : pets,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2621),
                  ),
                ),
              ),
              _StatusPill(
                label: review.reviewStatusDesc.isEmpty
                    ? '正常'
                    : review.reviewStatusDesc,
                backgroundColor: _reviewStatusBackground(review.reviewStatus),
                foregroundColor: _reviewStatusForeground(review.reviewStatus),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _metaText(review),
            style: const TextStyle(fontSize: 12, color: Color(0xFF8BA49A)),
          ),
        ],
      ),
    );
  }

  String _metaText(CaretakerReviewItem review) {
    final parts = <String>[];
    if (review.serviceDate.isNotEmpty) {
      parts.add(
        '服务日期 ${review.serviceDate.length >= 10 ? review.serviceDate.substring(0, 10) : review.serviceDate}',
      );
    }
    if (review.createdAt.isNotEmpty) {
      final created = review.createdAt.length >= 10
          ? review.createdAt.substring(0, 10)
          : review.createdAt;
      parts.add('评价时间 $created');
    }
    parts.add('订单 #${review.orderId}');
    return parts.join(' · ');
  }
}

class _ScoreCard extends StatelessWidget {
  final CaretakerReviewItem review;

  const _ScoreCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEBEBEB)),
      ),
      child: Column(
        children: [
          _ScoreRow(label: '综合评分', value: review.overallScore),
          const SizedBox(height: 12),
          _ScoreRow(label: '准时度', value: review.punctualityScore),
          const SizedBox(height: 12),
          _ScoreRow(label: '专业度', value: review.professionalScore),
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String label;
  final int value;

  const _ScoreRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: Color(0xFF1A2621)),
          ),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: List.generate(5, (index) {
              final score = index + 1;
              return Icon(
                score <= value ? Icons.star_rounded : Icons.star_border_rounded,
                color: score <= value
                    ? const Color(0xFFF1A628)
                    : const Color(0xFFC7D2CD),
                size: 22,
              );
            }),
          ),
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$value',
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF004D36),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReasonCard extends StatelessWidget {
  final List<ReviewDeductionReason> reasons;

  const _ReasonCard({required this.reasons});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEBEBEB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '扣分理由',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A2621),
            ),
          ),
          const SizedBox(height: 10),
          ...reasons.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.remove_circle_outline,
                    size: 16,
                    color: Color(0xFFD14B4B),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r.reasonText.isNotEmpty ? r.reasonText : r.reasonTypeDesc,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF5A6B62),
                        height: 1.45,
                      ),
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

class _CommentCard extends StatelessWidget {
  final String comment;

  const _CommentCard({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEBEBEB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '文字评价',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A2621),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            comment,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF2D3D36),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentCard extends StatelessWidget {
  final String title;
  final List<ReviewAttachment>? reviewAttachments;
  final List<String>? imageUrls;

  const _AttachmentCard({
    required this.title,
    this.reviewAttachments,
    this.imageUrls,
  });

  @override
  Widget build(BuildContext context) {
    final count = reviewAttachments?.length ?? imageUrls?.length ?? 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEBEBEB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title ($count)',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A2621),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: reviewAttachments != null
                ? reviewAttachments!.map((a) {
                    if (a.isVideo) {
                      return const _VideoThumb();
                    }
                    return _NetworkThumb(url: a.url);
                  }).toList()
                : (imageUrls ?? const <String>[])
                      .map((url) => _NetworkThumb(url: url))
                      .toList(),
          ),
        ],
      ),
    );
  }
}

class _AppealStatusCard extends StatelessWidget {
  final ReviewAppealDetail? appeal;
  final bool isLoading;

  const _AppealStatusCard({required this.appeal, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEBEBEB)),
      ),
      child: isLoading && appeal == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(
                  color: Color(0xFF004D36),
                  strokeWidth: 2,
                ),
              ),
            )
          : appeal == null
          ? const Text(
              '暂未查询到申诉记录',
              style: TextStyle(fontSize: 13, color: Color(0xFF8BA49A)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '申诉进度',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A2621),
                        ),
                      ),
                    ),
                    _StatusPill(
                      label: appeal!.appealStatusDesc.isEmpty
                          ? '处理中'
                          : appeal!.appealStatusDesc,
                      backgroundColor: _appealStatusBackground(
                        appeal!.appealStatus,
                      ),
                      foregroundColor: _appealStatusForeground(
                        appeal!.appealStatus,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _MetaRow(label: '申诉案号', value: '#${appeal!.appealId}'),
                _MetaRow(
                  label: '提交时间',
                  value: _formatDateTime(appeal!.createdAt),
                ),
                if (appeal!.appealDeadline.isNotEmpty)
                  _MetaRow(
                    label: '申诉时限',
                    value: _formatDateTime(appeal!.appealDeadline),
                  ),
                if (appeal!.closedAt.isNotEmpty)
                  _MetaRow(
                    label: '结案时间',
                    value: _formatDateTime(appeal!.closedAt),
                  ),
                const SizedBox(height: 12),
                const Text(
                  '申诉说明',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A2621),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  appeal!.reason.isEmpty ? '未填写申诉说明' : appeal!.reason,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF5A6B62),
                    height: 1.5,
                  ),
                ),
                if (appeal!.evidenceUrls.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _AttachmentCard(
                    title: '申诉证据',
                    imageUrls: appeal!.evidenceUrls,
                  ),
                ],
                const SizedBox(height: 12),
                _InfoBanner(
                  text: _appealMessage(appeal!),
                  accentColor: appeal!.isTerminal
                      ? _appealStatusForeground(appeal!.appealStatus)
                      : const Color(0xFFE9820A),
                  backgroundColor: appeal!.isTerminal
                      ? _appealStatusBackground(appeal!.appealStatus)
                      : const Color(0xFFFFF8ED),
                ),
                if (appeal!.adminMemo.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9F8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '平台处理说明',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A2621),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          appeal!.adminMemo,
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
              ],
            ),
    );
  }

  String _appealMessage(ReviewAppealDetail appeal) {
    switch (appeal.appealStatus) {
      case 1:
        return '平台已收到你的申诉，正在等待人工仲裁介入。';
      case 2:
        return '平台正在补充证据链，请留意后续处理结果。';
      case 3:
        return '平台已完成判定，结果即将同步到评价状态。';
      case 4:
        return '申诉成立，评价状态已更新。';
      case 5:
        return '申诉未通过，当前评价结果维持不变。';
      default:
        return '申诉处理中，请稍后刷新查看。';
    }
  }
}

class _AppealComposerCard extends StatelessWidget {
  final TextEditingController controller;
  final List<_AppealEvidenceDraft> evidence;
  final bool isUploading;
  final VoidCallback onAddEvidence;
  final ValueChanged<_AppealEvidenceDraft> onRemoveEvidence;

  const _AppealComposerCard({
    required this.controller,
    required this.evidence,
    required this.isUploading,
    required this.onAddEvidence,
    required this.onRemoveEvidence,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEBEBEB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '发起申诉',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A2621),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '请结合履约记录、门禁异常、沟通截图等材料说明情况，平台会人工复核。',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF5A6B62),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: 5,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: '例如：因小区门禁故障延迟 8 分钟到达，已提前电话告知宠主并补足服务时长',
              filled: true,
              fillColor: const Color(0xFFF7F9F8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text(
                '申诉证据',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A2621),
                ),
              ),
              const Spacer(),
              Text(
                '${evidence.length}/6',
                style: const TextStyle(fontSize: 12, color: Color(0xFF8BA49A)),
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
            onPressed: isUploading || evidence.length >= 6
                ? null
                : onAddEvidence,
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

class _NetworkThumb extends StatelessWidget {
  final String url;

  const _NetworkThumb({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
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
  final _AppealEvidenceDraft item;
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

class _VideoThumb extends StatelessWidget {
  const _VideoThumb();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: const Color(0xFF1A2621),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.play_circle_outline,
        color: Colors.white70,
        size: 32,
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String text;
  final Color? backgroundColor;
  final Color? accentColor;

  const _InfoBanner({
    required this.text,
    this.backgroundColor,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? const Color(0xFFFFF8ED);
    final fg = accentColor ?? const Color(0xFFE9820A);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: fg, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF8BA49A)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: Color(0xFF5A6B62)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  const _StatusPill({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: foregroundColor,
        ),
      ),
    );
  }
}

class _AppealBar extends StatelessWidget {
  final bool isSubmitting;
  final String deadline;
  final String buttonText;
  final VoidCallback onPressed;

  const _AppealBar({
    required this.isSubmitting,
    required this.deadline,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (deadline.isNotEmpty)
            Text(
              '申诉截止：${_formatDateTime(deadline)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF8BA49A)),
            ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: isSubmitting ? null : onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF004D36),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      buttonText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppealEvidenceDraft {
  final String localPath;
  final String url;

  const _AppealEvidenceDraft({required this.localPath, required this.url});
}

String _formatDateTime(String value) {
  if (value.isEmpty) return '--';
  if (value.length >= 16) {
    return value.substring(0, 16).replaceFirst('T', ' ');
  }
  return value.replaceFirst('T', ' ');
}

Color _reviewStatusBackground(int status) {
  switch (status) {
    case 2:
      return const Color(0xFFFFF8ED);
    case 3:
      return const Color(0xFFE8F2EF);
    case 4:
      return const Color(0xFFFFF3F0);
    default:
      return const Color(0xFFF0F5F3);
  }
}

Color _reviewStatusForeground(int status) {
  switch (status) {
    case 2:
      return const Color(0xFFE9820A);
    case 3:
      return const Color(0xFF004D36);
    case 4:
      return const Color(0xFFD14B4B);
    default:
      return const Color(0xFF5A6B62);
  }
}

Color _appealStatusBackground(int status) {
  switch (status) {
    case 4:
      return const Color(0xFFE8F2EF);
    case 5:
      return const Color(0xFFFFF3F0);
    default:
      return const Color(0xFFFFF8ED);
  }
}

Color _appealStatusForeground(int status) {
  switch (status) {
    case 4:
      return const Color(0xFF004D36);
    case 5:
      return const Color(0xFFD14B4B);
    default:
      return const Color(0xFFE9820A);
  }
}
