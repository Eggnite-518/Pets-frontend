import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:pets/core/network/api_client.dart';

import '../data/datasources/caretaker_training_remote_data_source.dart';

class CaretakerStudyMaterialScreen extends StatefulWidget {
  final String materialId;
  final bool readOnly;

  const CaretakerStudyMaterialScreen({
    super.key,
    required this.materialId,
    this.readOnly = false,
  });

  @override
  State<CaretakerStudyMaterialScreen> createState() =>
      _CaretakerStudyMaterialScreenState();
}

class _CaretakerStudyMaterialScreenState
    extends State<CaretakerStudyMaterialScreen> {
  late final CaretakerTrainingRemoteDataSource _ds;
  late final ScrollController _scrollController;
  Timer? _timer;

  TrainingMaterial? _material;
  bool _isLoading = true;
  bool _scrolledToBottom = false;
  bool _isAutoCompleting = false;
  int _elapsedSeconds = 0;
  String? _error;

  int get _materialIdInt => int.tryParse(widget.materialId) ?? 0;

  int get _remainingSeconds {
    final material = _material;
    if (material == null) return 0;
    return (material.minDurationSeconds - _elapsedSeconds).clamp(0, 99999);
  }

  @override
  void initState() {
    super.initState();
    _ds = CaretakerTrainingRemoteDataSource(ApiClient());
    _scrollController = ScrollController()..addListener(_onScroll);
    _loadMaterial();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    if (!widget.readOnly && !_isAutoCompleting) {
      _reportProgress();
    }
    super.dispose();
  }

  void _startStudyTimer() {
    if (widget.readOnly || _timer != null) return;
    final material = _material;
    if (material == null || material.completed) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _onTimerTick());
  }

  void _onTimerTick() {
    if (!mounted) return;
    setState(() => _elapsedSeconds++);

    if (_elapsedSeconds % 10 == 0) {
      _reportProgress();
    }

    if (_durationMet && !_isAutoCompleting) {
      _autoCompleteLesson();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 60) {
      if (!_scrolledToBottom) setState(() => _scrolledToBottom = true);
    }
  }

  Future<void> _loadMaterial() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final result = await _ds.getCurriculum();
    if (!mounted) return;
    result.when(
      success: (curriculum) {
        TrainingMaterial? found;
        for (final item in curriculum.materials) {
          if (item.materialId == _materialIdInt) {
            found = item;
            break;
          }
        }
        if (found == null) {
          setState(() {
            _error = '课程不存在';
            _isLoading = false;
          });
          return;
        }
        setState(() {
          _material = found;
          _elapsedSeconds = found!.watchedSeconds;
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _checkScrollAlreadyAtBottom();
          _startStudyTimer();
          if (_durationMet && !found!.completed && !widget.readOnly) {
            _autoCompleteLesson();
          }
        });
      },
      failure: (e) => setState(() {
        _error = e.message;
        _isLoading = false;
      }),
    );
  }

  void _checkScrollAlreadyAtBottom() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.maxScrollExtent <= 60) {
      setState(() => _scrolledToBottom = true);
    }
  }

  Future<void> _reportProgress({int? watchedSeconds}) async {
    if (widget.readOnly || _material == null) return;
    final watched = watchedSeconds ?? _elapsedSeconds;
    final result = await _ds.reportMaterialProgress(
      materialId: _materialIdInt,
      watchedSeconds: watched,
    );
    if (!mounted) return;
    result.when(
      success: (curriculum) {
        final updated = curriculum.materials
            .where((m) => m.materialId == _materialIdInt)
            .cast<TrainingMaterial?>()
            .firstWhere((m) => m != null, orElse: () => null);
        if (updated != null) {
          setState(() {
            _material = updated;
            if (updated.watchedSeconds > _elapsedSeconds) {
              _elapsedSeconds = updated.watchedSeconds;
            }
          });
        }
      },
      failure: (_) {},
    );
  }

  Future<void> _autoCompleteLesson() async {
    if (widget.readOnly || _isAutoCompleting || !_durationMet) return;
    _isAutoCompleting = true;
    _timer?.cancel();
    _timer = null;

    final minSeconds = _material!.minDurationSeconds;
    if (_elapsedSeconds < minSeconds) {
      setState(() => _elapsedSeconds = minSeconds);
    }
    await _reportProgress(watchedSeconds: minSeconds);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('本节必修课程已完成'),
        duration: Duration(seconds: 2),
      ),
    );
    context.pop(true);
  }

  bool get _durationMet {
    final material = _material;
    if (material == null) return false;
    return _elapsedSeconds >= material.minDurationSeconds;
  }

  bool get _canComplete =>
      widget.readOnly || _material?.completed == true || _durationMet;

  Future<void> _finishLesson() async {
    if (!_canComplete) return;
    if (!widget.readOnly) {
      await _reportProgress(
        watchedSeconds: _material!.minDurationSeconds,
      );
    }
    if (mounted) context.pop(true);
  }

  static String _formatCountdown(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(
        '/caretaker/training/study?readOnly=${widget.readOnly}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final material = _material;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9F8),
        elevation: 0,
        centerTitle: true,
        title: Text(
          material?.title ?? '课程学习',
          style: const TextStyle(
            color: Color(0xFF1A2621),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Color(0xFF5A6B62), size: 20),
          onPressed: _goBack,
        ),
        actions: [
          if (!widget.readOnly && material != null && !material.completed)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: _CountdownBadge(
                  remainingSeconds: _remainingSeconds,
                  durationMet: _durationMet,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF004D36)))
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    if (!widget.readOnly && !material!.completed)
                      _ProgressBanner(
                        material: material,
                        elapsedSeconds: _elapsedSeconds,
                        remainingSeconds: _remainingSeconds,
                      ),
                    Expanded(
                      child: material!.isVideo
                          ? _VideoLessonBody(
                              material: material,
                              elapsedSeconds: _elapsedSeconds,
                            )
                          : _DocLessonBody(
                              material: material,
                              scrollController: _scrollController,
                              scrolledToBottom: _scrolledToBottom,
                            ),
                    ),
                    _LessonBottomBar(
                      readOnly: widget.readOnly,
                      canComplete: _canComplete,
                      elapsedSeconds: _elapsedSeconds,
                      material: material,
                      onPressed: _finishLesson,
                    ),
                  ],
                ),
    );
  }
}

class _CountdownBadge extends StatelessWidget {
  final int remainingSeconds;
  final bool durationMet;

  const _CountdownBadge({
    required this.remainingSeconds,
    required this.durationMet,
  });

  @override
  Widget build(BuildContext context) {
    final done = durationMet || remainingSeconds <= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: done ? const Color(0xFFE8F2EF) : const Color(0xFFFFF8ED),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: done ? const Color(0xFF004D36) : const Color(0xFFE9820A),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_circle_outline : Icons.timer_outlined,
            size: 16,
            color: done ? const Color(0xFF004D36) : const Color(0xFFE9820A),
          ),
          const SizedBox(width: 4),
          Text(
            done
                ? '已完成'
                : _CaretakerStudyMaterialScreenState._formatCountdown(
                    remainingSeconds),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: done ? const Color(0xFF004D36) : const Color(0xFFE9820A),
              fontFeatures: done ? null : const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBanner extends StatelessWidget {
  final TrainingMaterial material;
  final int elapsedSeconds;
  final int remainingSeconds;

  const _ProgressBanner({
    required this.material,
    required this.elapsedSeconds,
    required this.remainingSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final done = remainingSeconds <= 0;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: done ? const Color(0xFFE8F2EF) : const Color(0xFFFFF8ED),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_outline : Icons.timer_outlined,
            size: 18,
            color: done ? const Color(0xFF004D36) : const Color(0xFFE9820A),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              done
                  ? '已达最短学习时长，正在标记本节完成…'
                  : '学习计时中 · 已学 ${elapsedSeconds}s / 至少 ${material.minDurationSeconds}s，倒计时结束自动完成',
              style: TextStyle(
                fontSize: 12,
                color: done ? const Color(0xFF004D36) : const Color(0xFF7A4A00),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoLessonBody extends StatelessWidget {
  final TrainingMaterial material;
  final int elapsedSeconds;

  const _VideoLessonBody({
    required this.material,
    required this.elapsedSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final remaining =
        (material.minDurationSeconds - elapsedSeconds).clamp(0, 9999);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: const Color(0xFF1A2621),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_circle_fill,
                    color: Colors.white70, size: 56),
                const SizedBox(height: 12),
                Text(
                  remaining > 0 ? '视频播放中 · 剩余 $remaining 秒' : '视频已观看完成',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                if (material.mediaUrl.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    material.mediaUrl,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          MarkdownBody(
            data: material.content,
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(
                fontSize: 14,
                color: Color(0xFF2D3D36),
                height: 1.7,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocLessonBody extends StatelessWidget {
  final TrainingMaterial material;
  final ScrollController scrollController;
  final bool scrolledToBottom;

  const _DocLessonBody({
    required this.material,
    required this.scrollController,
    required this.scrolledToBottom,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarkdownBody(
            data: material.content,
            styleSheet: MarkdownStyleSheet(
              h2: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF004D36),
              ),
              p: const TextStyle(
                fontSize: 14,
                color: Color(0xFF2D3D36),
                height: 1.85,
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (!scrolledToBottom)
            const Center(
              child: Text(
                '请滚动至文档底部',
                style: TextStyle(fontSize: 12, color: Color(0xFFB0C4BC)),
              ),
            ),
        ],
      ),
    );
  }
}

class _LessonBottomBar extends StatelessWidget {
  final bool readOnly;
  final bool canComplete;
  final int elapsedSeconds;
  final TrainingMaterial material;
  final VoidCallback onPressed;

  const _LessonBottomBar({
    required this.readOnly,
    required this.canComplete,
    required this.elapsedSeconds,
    required this.material,
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
          if (!readOnly)
            Text(
              material.completed
                  ? '本节已完成'
                  : '已学习 ${elapsedSeconds}s / 至少 ${material.minDurationSeconds}s',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF8BA49A)),
            ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: canComplete ? onPressed : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF004D36),
                disabledBackgroundColor: const Color(0xFFD0DDD8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                readOnly
                    ? '返回'
                    : material.completed
                        ? '返回课程列表'
                        : canComplete
                            ? '标记本节完成'
                            : '请继续学习…',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
