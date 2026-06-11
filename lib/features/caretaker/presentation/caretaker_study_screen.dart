import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pets/core/network/api_client.dart';

import '../data/datasources/caretaker_training_remote_data_source.dart';

class CaretakerStudyScreen extends StatefulWidget {
  final bool readOnly;

  const CaretakerStudyScreen({super.key, this.readOnly = false});

  @override
  State<CaretakerStudyScreen> createState() => _CaretakerStudyScreenState();
}

class _CaretakerStudyScreenState extends State<CaretakerStudyScreen> {
  late final CaretakerTrainingRemoteDataSource _ds;

  TrainingCurriculum? _curriculum;
  bool _isLoading = true;
  bool _isCompleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ds = CaretakerTrainingRemoteDataSource(ApiClient());
    _loadCurriculum();
  }

  Future<void> _loadCurriculum() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final result = await _ds.getCurriculum();
    if (!mounted) return;
    result.when(
      success: (data) => setState(() {
        _curriculum = data;
        _isLoading = false;
      }),
      failure: (e) => setState(() {
        _error = e.message;
        _isLoading = false;
      }),
    );
  }

  Future<void> _completeAndGoExam() async {
    if (widget.readOnly) {
      context.pop();
      return;
    }
    final curriculum = _curriculum;
    if (curriculum == null || !curriculum.allCompleted) {
      _showError('请先完成全部必修课程');
      return;
    }
    setState(() => _isCompleting = true);
    final result = await _ds.completeTraining();
    if (!mounted) return;
    setState(() => _isCompleting = false);
    result.when(
      success: (_) => context.pushReplacement('/caretaker/training/exam'),
      failure: (e) => _showError(e.message),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/caretaker/training');
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
        title: Text(
          widget.readOnly ? '复习课程' : '必修课程',
          style: const TextStyle(
            color: Color(0xFF1A2621),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Color(0xFF5A6B62), size: 20),
          onPressed: _goBack,
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF004D36)))
          : _error != null
              ? _ErrorBody(message: _error!, onRetry: _loadCurriculum)
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final curriculum = _curriculum!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '学习进度 ${curriculum.completedMaterialCount}/${curriculum.requiredMaterialCount}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A2621),
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: curriculum.requiredMaterialCount == 0
                      ? 0
                      : curriculum.completedMaterialCount /
                          curriculum.requiredMaterialCount,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFE2E8E5),
                  color: const Color(0xFF004D36),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '涵盖宠物行为学、牵引具使用、入户闭环、突发状况应急预案等模块。每门课需达到最短学习时长，不可快进跳过。',
                style: TextStyle(fontSize: 12, color: Color(0xFF5A6B62), height: 1.5),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: curriculum.materials.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              final material = curriculum.materials[index];
              return _CourseTile(
                material: material,
                readOnly: widget.readOnly,
                onTap: () async {
                  await context.push(
                    '/caretaker/training/study/${material.materialId}?readOnly=${widget.readOnly}',
                  );
                  if (mounted) _loadCurriculum();
                },
              );
            },
          ),
        ),
        if (!widget.readOnly)
          _BottomBar(
            enabled: curriculum.allCompleted && !_isCompleting,
            isLoading: _isCompleting,
            onPressed: _completeAndGoExam,
          ),
      ],
    );
  }
}

class _CourseTile extends StatelessWidget {
  final TrainingMaterial material;
  final bool readOnly;
  final VoidCallback onTap;

  const _CourseTile({
    required this.material,
    required this.readOnly,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final typeLabel = material.isVideo ? '视频' : '文档';
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
              color: material.completed
                  ? const Color(0xFF004D36)
                  : const Color(0xFFEBEBEB),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: material.completed
                      ? const Color(0xFFE8F2EF)
                      : const Color(0xFFF5F5F5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  material.isVideo
                      ? Icons.play_circle_outline
                      : Icons.menu_book_outlined,
                  color: material.completed
                      ? const Color(0xFF004D36)
                      : const Color(0xFF8BA49A),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      material.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A2621),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$typeLabel · 至少 ${material.minDurationSeconds} 秒'
                      '${material.watchedSeconds > 0 ? ' · 已学 ${material.watchedSeconds}s' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8BA49A),
                      ),
                    ),
                  ],
                ),
              ),
              if (material.completed)
                const Icon(Icons.check_circle, color: Color(0xFF004D36), size: 22)
              else
                const Icon(Icons.chevron_right, color: Color(0xFFB0C4BC)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final bool enabled;
  final bool isLoading;
  final VoidCallback onPressed;

  const _BottomBar({
    required this.enabled,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          onPressed: enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF004D36),
            disabledBackgroundColor: const Color(0xFFD0DDD8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : const Text(
                  '全部学完，去考试',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: Color(0xFF8BA49A), size: 48),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF5A6B62))),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF004D36)),
                foregroundColor: const Color(0xFF004D36),
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
