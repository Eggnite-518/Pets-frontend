import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pets/core/network/api_client.dart';

import '../data/datasources/caretaker_training_remote_data_source.dart';

class CaretakerTrainingScreen extends StatefulWidget {
  const CaretakerTrainingScreen({super.key});

  @override
  State<CaretakerTrainingScreen> createState() =>
      _CaretakerTrainingScreenState();
}

class _CaretakerTrainingScreenState extends State<CaretakerTrainingScreen> {
  late final CaretakerTrainingRemoteDataSource _ds;

  TrainingStatus? _status;
  TrainingCurriculum? _curriculum;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ds = CaretakerTrainingRemoteDataSource(ApiClient());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final result = await _ds.getStatus();
    if (!mounted) return;

    await result.when(
      success: (s) async {
        TrainingCurriculum? curriculum;
        if (s.realNameVerified) {
          final curriculumResult = await _ds.getCurriculum();
          curriculumResult.when(
            success: (data) => curriculum = data,
            failure: (_) {},
          );
        }
        if (!mounted) return;
        setState(() {
          _status = s;
          _curriculum = curriculum;
          _isLoading = false;
        });
      },
      failure: (e) {
        if (!mounted) return;
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _startOrContinue() async {
    final s = _status;
    if (s == null) return;

    if (!s.realNameVerified) {
      await _openAuth();
      return;
    }
    if (s.canStartExam) {
      await _openExam();
      return;
    }
    await _openStudy();
  }

  Future<void> _openAuth() async {
    await context.push('/caretaker/auth');
    if (mounted) {
      await _load();
    }
  }

  Future<void> _openStudy({bool readOnly = false}) async {
    await context.push('/caretaker/training/study?readOnly=$readOnly');
    if (mounted) {
      await _load();
    }
  }

  Future<void> _openExam() async {
    await context.push('/caretaker/training/exam');
    if (mounted) {
      await _load();
    }
  }

  Future<void> _reviewMaterial() async {
    await _openStudy(readOnly: true);
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/caretaker/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9F8),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text(
          '平台培训认证',
          style: TextStyle(
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
              ? _ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  color: const Color(0xFF004D36),
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_status!.resetReasonText != null) ...[
                          _ResetBanner(message: _status!.resetReasonText!),
                          const SizedBox(height: 16),
                        ],
                        _StatusBanner(status: _status!),
                        const SizedBox(height: 24),
                        const _StepTitle(text: '认证流程'),
                        const SizedBox(height: 16),
                        _StepList(
                          status: _status!,
                          curriculum: _curriculum,
                          onReviewMaterial: _reviewMaterial,
                          onGoAuth: _openAuth,
                          onStartMaterial: _openStudy,
                        ),
                        const SizedBox(height: 28),
                        const _RuleCard(),
                        const SizedBox(height: 32),
                        if (!_status!.isPassed)
                          _ActionButton(
                            status: _status!,
                            onPressed: _startOrContinue,
                          ),
                        if (_status!.isPassed) ...[
                          _ReviewButton(onPressed: _reviewMaterial),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }
}

// ── 顶部状态横幅 ──────────────────────────────────────────────────────────────

class _ResetBanner extends StatelessWidget {
  final String message;

  const _ResetBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0C4BC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFD14B4B), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF7A2E2E),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 顶部状态横幅 ──────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final TrainingStatus status;

  const _StatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    if (status.isPassed) {
      return _banner(
        icon: Icons.verified_rounded,
        iconColor: Colors.white,
        iconBg: const Color(0xFF004D36),
        bg: const Color(0xFFE8F2EF),
        title: '认证已通过',
        subtitle: '你已获得平台宠托师接单资格',
        titleColor: const Color(0xFF004D36),
        subtitleColor: const Color(0xFF3D6B59),
      );
    }
    if (status.verifyStatus == 1) {
      return _banner(
        icon: Icons.menu_book_outlined,
        iconColor: Colors.white,
        iconBg: const Color(0xFFE9820A),
        bg: const Color(0xFFFFF8ED),
        title: status.canStartExam ? '学习已完成，待参加考试' : '培训进行中',
        subtitle: status.canStartExam
            ? '完成 20 道考题（≥90分）即可获得接单资格'
            : '请完成培训材料学习后参加考试',
        titleColor: const Color(0xFF7A4A00),
        subtitleColor: const Color(0xFF9B6A00),
      );
    }
    return _banner(
      icon: Icons.school_outlined,
      iconColor: Colors.white,
      iconBg: const Color(0xFF5A6B62),
      bg: const Color(0xFFF0F5F3),
      title: '尚未开始培训',
      subtitle: '完成认证后才能在接单大厅接单',
      titleColor: const Color(0xFF1A2621),
      subtitleColor: const Color(0xFF5A6B62),
    );
  }

  Widget _banner({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Color bg,
    required String title,
    required String subtitle,
    required Color titleColor,
    required Color subtitleColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: titleColor)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style:
                        TextStyle(fontSize: 13, color: subtitleColor, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 步骤列表 ──────────────────────────────────────────────────────────────────

class _StepTitle extends StatelessWidget {
  final String text;
  const _StepTitle({required this.text});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A2621)),
      );
}

class _StepList extends StatelessWidget {
  final TrainingStatus status;
  final TrainingCurriculum? curriculum;
  final VoidCallback onReviewMaterial;
  final VoidCallback onGoAuth;
  final VoidCallback onStartMaterial;

  const _StepList({
    required this.status,
    this.curriculum,
    required this.onReviewMaterial,
    required this.onGoAuth,
    required this.onStartMaterial,
  });

  String _learningSubtitle() {
    if (!status.realNameVerified) {
      return '完成实名认证后可开始学习';
    }
    final requiredCount = curriculum?.requiredMaterialCount ??
        status.requiredMaterialCount;
    final completedCount = curriculum?.completedMaterialCount ??
        status.completedMaterialCount;
    if (requiredCount <= 0) {
      return '课程加载中，请稍后刷新';
    }
    return '已完成 $completedCount/$requiredCount 门 · 行为学/牵引/入户/应急';
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      _StepData(
        icon: Icons.badge_outlined,
        title: '实名认证',
        subtitle: '确认服务者身份合规',
        done: status.realNameVerified,
        active: !status.realNameVerified,
        tapHint: status.realNameVerified ? null : '去认证',
        onTap: status.realNameVerified ? null : onGoAuth,
      ),
      _StepData(
        icon: Icons.menu_book_outlined,
        title: '学习培训材料',
        subtitle: _learningSubtitle(),
        done: status.learningCompleted || status.isPassed,
        active: status.realNameVerified &&
            !status.learningCompleted &&
            !status.isPassed,
        tapHint: (status.learningCompleted || status.isPassed) ? '点击复习' : null,
        onTap: (status.learningCompleted || status.isPassed)
            ? onReviewMaterial
            : (status.realNameVerified ? onStartMaterial : null),
      ),
      _StepData(
        icon: Icons.assignment_outlined,
        title: '通过资格考试',
        subtitle: '20 题，≥90 分且核心题全对',
        done: status.isPassed,
        active: status.canStartExam,
        extraInfo: status.lastExamScore != null && !status.isPassed
            ? '上次得分：${status.lastExamScore} 分'
            : null,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEBEBEB)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            _StepRow(step: steps[i], isLast: i == steps.length - 1),
          ],
        ],
      ),
    );
  }
}

class _StepData {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool done;
  final bool active;
  final String? extraInfo;
  final String? tapHint;
  final VoidCallback? onTap;

  const _StepData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.done,
    required this.active,
    this.extraInfo,
    this.tapHint,
    this.onTap,
  });
}

class _StepRow extends StatelessWidget {
  final _StepData step;
  final bool isLast;

  const _StepRow({required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    Color iconBg;
    Color iconColor;
    if (step.done) {
      iconBg = const Color(0xFFE8F2EF);
      iconColor = const Color(0xFF004D36);
    } else if (step.active) {
      iconBg = const Color(0xFFFFF3DC);
      iconColor = const Color(0xFFE9820A);
    } else {
      iconBg = const Color(0xFFF5F5F5);
      iconColor = const Color(0xFFB0C4BC);
    }

    return Column(
      children: [
        InkWell(
          onTap: step.onTap,
          borderRadius: isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(16))
              : BorderRadius.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration:
                      BoxDecoration(color: iconBg, shape: BoxShape.circle),
                  child: Icon(step.icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: step.done || step.active
                              ? const Color(0xFF1A2621)
                              : const Color(0xFFB0C4BC),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: step.done || step.active
                              ? const Color(0xFF8BA49A)
                              : const Color(0xFFCDD8D4),
                        ),
                      ),
                      if (step.extraInfo != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3DC),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            step.extraInfo!,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFFE9820A)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (step.done && step.tapHint != null) ...[
                  Text(
                    step.tapHint!,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF004D36)),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right,
                      color: Color(0xFF004D36), size: 18),
                ] else if (step.active && step.onTap != null && step.tapHint != null) ...[
                  Text(
                    step.tapHint!,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFFE9820A)),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right,
                      color: Color(0xFFE9820A), size: 18),
                ] else if (step.done) ...[
                  const Icon(Icons.check_circle,
                      color: Color(0xFF004D36), size: 20),
                ],
              ],
            ),
          ),
        ),
        if (!isLast)
          const Divider(
              height: 1, thickness: 1, color: Color(0xFFF5F5F5), indent: 70),
      ],
    );
  }
}

// ── 考核规则卡片 ──────────────────────────────────────────────────────────────

class _RuleCard extends StatelessWidget {
  const _RuleCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5F3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline, color: Color(0xFF5A6B62), size: 16),
              SizedBox(width: 6),
              Text(
                '考核说明',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A2621)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ruleItem('共20道选择题，15道基础题 + 5道核心安全题'),
          _ruleItem('总分100分，每题5分，合格线90分'),
          _ruleItem('核心安全题一票否决，错一道即不通过'),
          _ruleItem('不通过可重新学习后再次参加考试'),
          _ruleItem('被投诉或长期未接单将重置认证，需重考'),
        ],
      ),
    );
  }

  Widget _ruleItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: CircleAvatar(
                radius: 2.5, backgroundColor: Color(0xFF8BA49A)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF5A6B62), height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 操作按钮 ──────────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final TrainingStatus status;
  final VoidCallback onPressed;

  const _ActionButton({required this.status, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final label = !status.realNameVerified
        ? '去实名认证'
        : status.canStartExam
            ? '开始考试'
            : status.verifyStatus == 1
                ? '继续学习'
                : '开始学习';

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF004D36),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ── 复习按钮（认证已通过时显示）─────────────────────────────────────────────────

class _ReviewButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ReviewButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.menu_book_outlined, size: 18),
        label: const Text(
          '复习培训材料',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF004D36)),
          foregroundColor: const Color(0xFF004D36),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

// ── 错误视图 ──────────────────────────────────────────────────────────────────

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
