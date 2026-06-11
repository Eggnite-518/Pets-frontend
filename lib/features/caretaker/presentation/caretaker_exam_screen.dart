import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pets/core/network/api_client.dart';

import '../data/datasources/caretaker_training_remote_data_source.dart';

class CaretakerExamScreen extends StatefulWidget {
  const CaretakerExamScreen({super.key});

  @override
  State<CaretakerExamScreen> createState() => _CaretakerExamScreenState();
}

class _CaretakerExamScreenState extends State<CaretakerExamScreen> {
  late final CaretakerTrainingRemoteDataSource _ds;
  late final PageController _pageController;

  List<ExamQuestion> _questions = [];
  final Map<int, String> _answers = {};
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _ds = CaretakerTrainingRemoteDataSource(ApiClient());
    _pageController = PageController();
    _loadExam();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadExam() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final result = await _ds.startExam();
    if (!mounted) return;
    result.when(
      success: (qs) => setState(() {
        _questions = qs;
        _isLoading = false;
      }),
      failure: (e) => setState(() {
        _error = e.message;
        _isLoading = false;
      }),
    );
  }

  void _onOptionSelected(ExamQuestion question, String option) {
    setState(() {
      _answers[question.questionId] = option;
    });

    final isLast = _currentPage == _questions.length - 1;
    if (isLast) return;

    // 短暂延迟后自动进入下一题
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _submit() async {
    final unanswered = _questions.where((q) => !_answers.containsKey(q.questionId)).length;
    if (unanswered > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('还有 $unanswered 道题未作答'),
          backgroundColor: const Color(0xFFE9820A),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('确认提交'),
        content: const Text('提交后无法修改，确定要交卷吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('再看看',
                style: TextStyle(color: Color(0xFF5A6B62))),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF004D36),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('确认提交'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isSubmitting = true);
    final result = await _ds.submitExam(_answers);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    result.when(
      success: (examResult) => _showResult(examResult),
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: const Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
        ),
      ),
    );
  }

  void _showResult(ExamResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _ExamResultDialog(
        result: result,
        onOk: () {
          Navigator.pop(dialogContext);
          if (result.passed) {
            context.go('/caretaker/training');
            return;
          }
          _goBack();
        },
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
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: _isLoading || _questions.isEmpty
            ? const Text('资格考试',
                style: TextStyle(
                    color: Color(0xFF1A2621),
                    fontSize: 18,
                    fontWeight: FontWeight.w700))
            : _ProgressTitle(
                current: _currentPage + 1,
                total: _questions.length,
                answered: _answers.length,
              ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Color(0xFF5A6B62), size: 20),
          onPressed: () => _confirmBack(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF004D36)))
          : _error != null
              ? _ErrorBody(message: _error!, onRetry: _loadExam)
              : Column(
                  children: [
                    _ProgressBar(
                      current: _currentPage + 1,
                      total: _questions.length,
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        physics: const ClampingScrollPhysics(),
                        onPageChanged: (i) =>
                            setState(() => _currentPage = i),
                        itemCount: _questions.length,
                        itemBuilder: (_, i) => _QuestionPage(
                          question: _questions[i],
                          questionIndex: i,
                          totalCount: _questions.length,
                          selectedOption:
                              _answers[_questions[i].questionId],
                          onOptionSelected: (opt) =>
                              _onOptionSelected(_questions[i], opt),
                        ),
                      ),
                    ),
                    _BottomNav(
                      currentPage: _currentPage,
                      totalPages: _questions.length,
                      isLastPage: _currentPage == _questions.length - 1,
                      isSubmitting: _isSubmitting,
                      allAnswered: _answers.length == _questions.length,
                      onPrev: () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut),
                      onNext: () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut),
                      onSubmit: _submit,
                    ),
                  ],
                ),
    );
  }

  Future<void> _confirmBack() async {
    if (_answers.isEmpty) {
      _goBack();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('退出考试'),
        content: const Text('退出后已选答案将丢失，确定要退出吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('继续作答',
                style: TextStyle(color: Color(0xFF5A6B62))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('退出', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) _goBack();
  }
}

// ── AppBar 进度标题 ───────────────────────────────────────────────────────────

class _ProgressTitle extends StatelessWidget {
  final int current;
  final int total;
  final int answered;

  const _ProgressTitle(
      {required this.current,
      required this.total,
      required this.answered});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '第 $current/$total 题',
          style: const TextStyle(
              color: Color(0xFF1A2621),
              fontSize: 18,
              fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 8),
        Text(
          '已答 $answered 题',
          style: const TextStyle(
              color: Color(0xFF8BA49A), fontSize: 13),
        ),
      ],
    );
  }
}

// ── 顶部进度条 ────────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final int current;
  final int total;

  const _ProgressBar({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      color: const Color(0xFFE8EFE9),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: current / total,
        child: Container(color: const Color(0xFF004D36)),
      ),
    );
  }
}

// ── 题目页 ────────────────────────────────────────────────────────────────────

class _QuestionPage extends StatelessWidget {
  final ExamQuestion question;
  final int questionIndex;
  final int totalCount;
  final String? selectedOption;
  final ValueChanged<String> onOptionSelected;

  const _QuestionPage({
    required this.question,
    required this.questionIndex,
    required this.totalCount,
    required this.selectedOption,
    required this.onOptionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 题型标签
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: question.isCore
                      ? const Color(0xFFFFECEC)
                      : const Color(0xFFE8F2EF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  question.isCore ? '核心安全题' : '基础题',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: question.isCore
                        ? const Color(0xFFD32F2F)
                        : const Color(0xFF004D36),
                  ),
                ),
              ),
              if (question.isCore) ...[
                const SizedBox(width: 6),
                const Text(
                  '此题错误将直接不通过',
                  style: TextStyle(fontSize: 12, color: Color(0xFFD32F2F)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          // 题目
          Text(
            '${questionIndex + 1}. ${question.content}',
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A2621),
                height: 1.5),
          ),
          const SizedBox(height: 24),
          // 选项列表
          ...List.generate(question.options.length, (i) {
            final labels = ['A', 'B', 'C', 'D'];
            final label = i < labels.length ? labels[i] : '${i + 1}';
            final option = question.options[i];
            final isSelected = selectedOption == option;

            return _OptionTile(
              label: label,
              text: option,
              isSelected: isSelected,
              onTap: () => onOptionSelected(option),
            );
          }),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F2EF) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF004D36)
                : const Color(0xFFE0E8E4),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF004D36)
                    : const Color(0xFFF5F5F5),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : const Color(0xFF8BA49A),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 15,
                  color: isSelected
                      ? const Color(0xFF004D36)
                      : const Color(0xFF2D3D36),
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                  height: 1.4,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle,
                  color: Color(0xFF004D36), size: 20),
          ],
        ),
      ),
    );
  }
}

// ── 底部导航 ──────────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final bool isLastPage;
  final bool isSubmitting;
  final bool allAnswered;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onSubmit;

  const _BottomNav({
    required this.currentPage,
    required this.totalPages,
    required this.isLastPage,
    required this.isSubmitting,
    required this.allAnswered,
    required this.onPrev,
    required this.onNext,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Color(0x15000000), blurRadius: 8, offset: Offset(0, -2)),
        ],
      ),
      child: Row(
        children: [
          if (currentPage > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: onPrev,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF004D36),
                  side: const BorderSide(color: Color(0xFF004D36)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('上一题',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          if (currentPage > 0) const SizedBox(width: 12),
          Expanded(
            flex: isLastPage ? 1 : 1,
            child: isLastPage
                ? FilledButton(
                    onPressed: isSubmitting ? null : onSubmit,
                    style: FilledButton.styleFrom(
                      backgroundColor: allAnswered
                          ? const Color(0xFF004D36)
                          : const Color(0xFFB0C4BC),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text('交卷',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                  )
                : FilledButton(
                    onPressed: onNext,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF004D36),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('下一题',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── 考试结果弹窗 ──────────────────────────────────────────────────────────────

class _ExamResultDialog extends StatelessWidget {
  final ExamResult result;
  final VoidCallback onOk;

  const _ExamResultDialog({required this.result, required this.onOk});

  @override
  Widget build(BuildContext context) {
    final passed = result.passed;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: EdgeInsets.zero,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部颜色块
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              color: passed
                  ? const Color(0xFF004D36)
                  : const Color(0xFFD32F2F),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Icon(
                  passed ? Icons.emoji_events_rounded : Icons.close_rounded,
                  color: Colors.white,
                  size: 52,
                ),
                const SizedBox(height: 10),
                Text(
                  passed ? '恭喜，考试通过！' : '很遗憾，未通过',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          // 分数与信息
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Column(
              children: [
                Text(
                  '${result.score} 分',
                  style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      color: passed
                          ? const Color(0xFF004D36)
                          : const Color(0xFFD32F2F)),
                ),
                const SizedBox(height: 6),
                Text(
                  '合格线 90 分',
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF8BA49A)),
                ),
                const SizedBox(height: 16),
                if (!result.corePassed)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFECEC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '核心安全题未全部正确，本次不通过',
                      style: TextStyle(
                          fontSize: 13, color: Color(0xFFD32F2F)),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (!result.corePassed) const SizedBox(height: 8),
                Text(
                  passed
                      ? '你已获得平台宠托师接单资格，可在接单大厅接单了！'
                      : '请重新阅读培训材料后再次参加考试',
                  style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF5A6B62),
                      height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // 按钮
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: onOk,
                style: FilledButton.styleFrom(
                  backgroundColor: passed
                      ? const Color(0xFF004D36)
                      : const Color(0xFF5A6B62),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  passed ? '开始接单' : '重新学习',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 错误视图 ──────────────────────────────────────────────────────────────────

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
