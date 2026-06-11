import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pets/core/network/api_client.dart';
import 'package:pets/core/network/api_exception.dart';
import 'package:pets/features/owner/data/datasources/review_remote_data_source.dart';
import 'package:pets/features/owner/data/models/order_rating_detail_model.dart';
import 'package:pets/features/owner/data/models/review_attachment_model.dart';
import 'package:pets/features/owner/data/models/submit_order_review_request.dart';

class OrderReviewScreen extends StatefulWidget {
  const OrderReviewScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<OrderReviewScreen> createState() => _OrderReviewScreenState();
}

class _OrderReviewScreenState extends State<OrderReviewScreen> {
  static const List<_DeductionReasonOption> _deductionReasonOptions = [
    _DeductionReasonOption(1, '未按时到达'),
    _DeductionReasonOption(2, '未按要求喂食'),
    _DeductionReasonOption(3, '宠物异常未及时反馈'),
    _DeductionReasonOption(4, '打卡记录缺失'),
    _DeductionReasonOption(5, '服务态度差'),
    _DeductionReasonOption(6, '其他'),
  ];

  final ApiClient _apiClient = ApiClient();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _commentController = TextEditingController();
  late final ReviewRemoteDataSource _reviewRemoteDataSource;

  int _overallScore = 5;
  int _punctualityScore = 5;
  int _professionalScore = 5;
  bool _isSubmitting = false;
  bool _isUploadingAttachment = false;
  bool _isLoadingRating = true;
  OrderRatingDetailModel? _existingRating;
  final Set<int> _selectedReasonTypes = {};
  final List<_ReviewAttachmentDraft> _attachments = [];

  bool get _isLowScore =>
      _overallScore <= 3 || _punctualityScore <= 3 || _professionalScore <= 3;

  @override
  void initState() {
    super.initState();
    _reviewRemoteDataSource = ReviewRemoteDataSource(_apiClient);
    _loadExistingRating();
  }

  @override
  void dispose() {
    _reviewRemoteDataSource.close();
    _apiClient.close();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAttachment(
    ImageSource source,
    bool isVideo,
  ) async {
    if (_isUploadingAttachment || _attachments.length >= 6) return;

    final XFile? pickedFile = isVideo
        ? await _imagePicker.pickVideo(source: source)
        : await _imagePicker.pickImage(source: source, imageQuality: 85);
    if (pickedFile == null) return;

    setState(() => _isUploadingAttachment = true);

    try {
      final response = await _reviewRemoteDataSource.uploadAttachment(
        filePath: pickedFile.path,
      );
      if (!mounted) return;

      if (!response.isSuccess || response.data == null) {
        _showSnackBar(response.message.isEmpty ? '附件上传失败' : response.message);
        return;
      }

      setState(() {
        _attachments.add(
          _ReviewAttachmentDraft(
            attachment: response.data!,
            localPath: pickedFile.path,
          ),
        );
      });
    } on ApiException catch (error) {
      if (mounted) _showSnackBar(error.message);
    } catch (_) {
      if (mounted) _showSnackBar('附件上传失败');
    } finally {
      if (mounted) setState(() => _isUploadingAttachment = false);
    }
  }

  Future<void> _loadExistingRating() async {
    try {
      final response = await _reviewRemoteDataSource.getRating(
        orderId: widget.orderId,
      );
      if (!mounted) return;
      setState(() {
        _existingRating = response.data;
        _isLoadingRating = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _isLoadingRating = false);
      _showSnackBar(error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingRating = false);
      _showSnackBar('获取评价详情失败');
    }
  }

  Future<void> _showAttachmentPicker() async {
    final type = await showModalBottomSheet<_AttachmentPickType>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('选择图片'),
                onTap: () => Navigator.pop(context, _AttachmentPickType.image),
              ),
              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: const Text('选择视频'),
                onTap: () => Navigator.pop(context, _AttachmentPickType.video),
              ),
            ],
          ),
        );
      },
    );

    if (type == null) return;
    await _pickAndUploadAttachment(
      ImageSource.gallery,
      type == _AttachmentPickType.video,
    );
  }

  Future<void> _submitReview() async {
    if (_isSubmitting || _isUploadingAttachment) return;

    final comment = _commentController.text.trim();
    if (_isLowScore && comment.isEmpty) {
      _showSnackBar('低分评价请填写评价内容');
      return;
    }
    if (_isLowScore && _selectedReasonTypes.isEmpty) {
      _showSnackBar('低分评价请选择扣分原因');
      return;
    }

    setState(() => _isSubmitting = true);

    final request = SubmitOrderReviewRequest(
      overallScore: _overallScore,
      punctualityScore: _punctualityScore,
      professionalScore: _professionalScore,
      comment: comment,
      deductionReasons: _isLowScore
          ? _selectedReasonTypes
                .map(
                  (reasonType) => ReviewDeductionReasonRequest(
                    reasonType: reasonType,
                    reasonText: reasonType == 6 ? '其他' : null,
                  ),
                )
                .toList()
          : const [],
      attachments: _attachments
          .map((draft) => draft.attachment)
          .toList(growable: false),
    );

    try {
      final response = await _reviewRemoteDataSource.submitReview(
        orderId: widget.orderId,
        request: request,
      );
      if (!mounted) return;

      if (!response.isSuccess) {
        _showSnackBar(response.message.isEmpty ? '提交评价失败' : response.message);
        return;
      }

      _showSnackBar('评价已提交');
      context.pop(true);
    } on ApiException catch (error) {
      if (mounted) _showSnackBar(error.message);
    } catch (_) {
      if (mounted) _showSnackBar('提交评价失败');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _setScore(_ScoreKind kind, int score) {
    setState(() {
      switch (kind) {
        case _ScoreKind.overall:
          _overallScore = score;
        case _ScoreKind.punctuality:
          _punctualityScore = score;
        case _ScoreKind.professional:
          _professionalScore = score;
      }

      if (!_isLowScore) {
        _selectedReasonTypes.clear();
      }
    });
  }

  void _toggleReason(int reasonType) {
    setState(() {
      if (_selectedReasonTypes.contains(reasonType)) {
        _selectedReasonTypes.remove(reasonType);
      } else {
        _selectedReasonTypes.add(reasonType);
      }
    });
  }

  void _removeAttachment(_ReviewAttachmentDraft attachment) {
    setState(() => _attachments.remove(attachment));
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = !_isSubmitting && !_isUploadingAttachment;
    final existingRating = _existingRating;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        title: Text(
          existingRating == null ? '评价订单 #${widget.orderId}' : '查看评价',
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoadingRating
          ? const Center(child: CircularProgressIndicator())
          : existingRating != null
          ? _ExistingRatingView(rating: existingRating)
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Section(
                    title: '服务评分',
                    child: Column(
                      children: [
                        _ScoreRow(
                          label: '综合评分',
                          value: _overallScore,
                          onChanged: (score) =>
                              _setScore(_ScoreKind.overall, score),
                        ),
                        const SizedBox(height: 14),
                        _ScoreRow(
                          label: '准时度',
                          value: _punctualityScore,
                          onChanged: (score) =>
                              _setScore(_ScoreKind.punctuality, score),
                        ),
                        const SizedBox(height: 14),
                        _ScoreRow(
                          label: '专业度',
                          value: _professionalScore,
                          onChanged: (score) =>
                              _setScore(_ScoreKind.professional, score),
                        ),
                      ],
                    ),
                  ),
                  if (_isLowScore) ...[
                    const SizedBox(height: 14),
                    _Section(
                      title: '扣分原因',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _deductionReasonOptions.map((option) {
                          final selected = _selectedReasonTypes.contains(
                            option.reasonType,
                          );
                          return FilterChip(
                            selected: selected,
                            label: Text(option.label),
                            onSelected: (_) => _toggleReason(option.reasonType),
                            selectedColor: const Color(0xFFE8F2EF),
                            checkmarkColor: const Color(0xFF004D36),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _Section(
                    title: '评价内容',
                    child: TextField(
                      controller: _commentController,
                      minLines: 4,
                      maxLines: 6,
                      decoration: InputDecoration(
                        hintText: _isLowScore ? '请说明具体问题' : '写下这次服务体验',
                        filled: true,
                        fillColor: const Color(0xFFF4F7F6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Section(
                    title: '评价附件',
                    trailing: '${_attachments.length}/6',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_attachments.isNotEmpty)
                          SizedBox(
                            height: 84,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _attachments.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (_, index) {
                                final attachment = _attachments[index];
                                return _AttachmentPreview(
                                  attachment: attachment,
                                  onRemove: () => _removeAttachment(attachment),
                                );
                              },
                            ),
                          ),
                        if (_attachments.isNotEmpty) const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed:
                              _isUploadingAttachment ||
                                  _isSubmitting ||
                                  _attachments.length >= 6
                              ? null
                              : _showAttachmentPicker,
                          icon: _isUploadingAttachment
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.add_photo_alternate_outlined),
                          label: Text(
                            _isUploadingAttachment ? '上传中' : '添加图片/视频',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: canSubmit ? _submitReview : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF004D36),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            '提交评价',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ExistingRatingView extends StatelessWidget {
  final OrderRatingDetailModel rating;

  const _ExistingRatingView({required this.rating});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Section(
            title: '服务评分',
            trailing: rating.reviewStatusDesc.isEmpty
                ? null
                : rating.reviewStatusDesc,
            child: Column(
              children: [
                _ReadonlyScoreRow(label: '综合评分', value: rating.overallScore),
                const SizedBox(height: 14),
                _ReadonlyScoreRow(label: '准时度', value: rating.punctualityScore),
                const SizedBox(height: 14),
                _ReadonlyScoreRow(
                  label: '专业度',
                  value: rating.professionalScore,
                ),
              ],
            ),
          ),
          if (rating.deductionReasons.isNotEmpty) ...[
            const SizedBox(height: 14),
            _Section(
              title: '扣分原因',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: rating.deductionReasons
                    .map(
                      (reason) => Chip(
                        label: Text(
                          reason.reasonText.isNotEmpty
                              ? reason.reasonText
                              : reason.reasonTypeDesc,
                        ),
                        backgroundColor: const Color(0xFFE8F2EF),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 14),
          _Section(
            title: '评价内容',
            child: Text(
              rating.comment.isEmpty ? '暂无评价内容' : rating.comment,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1A2621),
                height: 1.5,
              ),
            ),
          ),
          if (rating.attachments.isNotEmpty) ...[
            const SizedBox(height: 14),
            _Section(
              title: '评价附件',
              trailing: '${rating.attachments.length}/6',
              child: SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: rating.attachments.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, index) {
                    return _ExistingAttachmentPreview(
                      attachment: rating.attachments[index],
                    );
                  },
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          OutlinedButton(
            onPressed: () => context.pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: const Text('返回'),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String? trailing;
  final Widget child;

  const _Section({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A2621),
                ),
              ),
              const Spacer(),
              if (trailing != null)
                Text(
                  trailing!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8BA49A),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _ScoreRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final buttonSize = (constraints.maxWidth / 5).clamp(0.0, 38.0);
              final iconSize = (buttonSize - 8).clamp(0.0, 30.0);

              return Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: List.generate(5, (index) {
                  final score = index + 1;
                  final selected = score <= value;

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(score),
                    child: SizedBox(
                      width: buttonSize,
                      height: 38,
                      child: Center(
                        child: Icon(
                          selected
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: selected
                              ? const Color(0xFFF1A628)
                              : const Color(0xFFC7D2CD),
                          size: iconSize,
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
        SizedBox(
          width: 32,
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

class _ReadonlyScoreRow extends StatelessWidget {
  final String label;
  final int value;

  const _ReadonlyScoreRow({required this.label, required this.value});

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
              final selected = index + 1 <= value;
              return Icon(
                selected ? Icons.star_rounded : Icons.star_border_rounded,
                color: selected
                    ? const Color(0xFFF1A628)
                    : const Color(0xFFC7D2CD),
                size: 28,
              );
            }),
          ),
        ),
        SizedBox(
          width: 32,
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

class _AttachmentPreview extends StatelessWidget {
  final _ReviewAttachmentDraft attachment;
  final VoidCallback onRemove;

  const _AttachmentPreview({required this.attachment, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final isImage = attachment.attachment.mediaType.toUpperCase() == 'IMAGE';

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
          child: isImage
              ? Image.file(File(attachment.localPath), fit: BoxFit.cover)
              : const Center(
                  child: Icon(
                    Icons.play_circle_outline,
                    color: Color(0xFF004D36),
                    size: 34,
                  ),
                ),
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

class _ExistingAttachmentPreview extends StatelessWidget {
  final OrderRatingAttachmentModel attachment;

  const _ExistingAttachmentPreview({required this.attachment});

  @override
  Widget build(BuildContext context) {
    final isImage = attachment.mediaType.toUpperCase() == 'IMAGE';

    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8E5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: isImage && attachment.url.isNotEmpty
          ? Image.network(attachment.url, fit: BoxFit.cover)
          : const Center(
              child: Icon(
                Icons.play_circle_outline,
                color: Color(0xFF004D36),
                size: 34,
              ),
            ),
    );
  }
}

class _ReviewAttachmentDraft {
  final ReviewAttachmentModel attachment;
  final String localPath;

  const _ReviewAttachmentDraft({
    required this.attachment,
    required this.localPath,
  });
}

class _DeductionReasonOption {
  final int reasonType;
  final String label;

  const _DeductionReasonOption(this.reasonType, this.label);
}

enum _ScoreKind { overall, punctuality, professional }

enum _AttachmentPickType { image, video }
