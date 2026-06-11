import 'package:pets/core/network/api_client.dart';
import 'package:pets/core/network/api_exception.dart';
import 'package:pets/core/network/api_result.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

class TrainingStatus {
  /// 0=未开始, 1=学习中, 2=已通过
  final int verifyStatus;
  final bool realNameVerified;
  final bool learningCompleted;
  final int? lastExamScore;
  final bool? lastExamPassed;
  final String? resetReason;
  final int requiredMaterialCount;
  final int completedMaterialCount;
  final int learningProgressPercent;

  const TrainingStatus({
    required this.verifyStatus,
    required this.realNameVerified,
    required this.learningCompleted,
    this.lastExamScore,
    this.lastExamPassed,
    this.resetReason,
    this.requiredMaterialCount = 0,
    this.completedMaterialCount = 0,
    this.learningProgressPercent = 0,
  });

  factory TrainingStatus.fromJson(Map<String, dynamic> json) {
    final requiredMaterialCount =
        (json['requiredMaterialCount'] as num?)?.toInt() ?? 0;
    final completedMaterialCount =
        (json['completedMaterialCount'] as num?)?.toInt() ?? 0;
    final learningCompletedAt = json['learningCompletedAt'];
    final learningCompleted = json['learningCompleted'] == true ||
        (learningCompletedAt != null &&
            learningCompletedAt.toString().isNotEmpty) ||
        (requiredMaterialCount > 0 &&
            completedMaterialCount >= requiredMaterialCount);

    return TrainingStatus(
      verifyStatus: (json['verifyStatus'] as num?)?.toInt() ?? 0,
      realNameVerified: json['realNameVerified'] as bool? ?? false,
      learningCompleted: learningCompleted,
      lastExamScore: (json['lastExamScore'] as num?)?.toInt(),
      lastExamPassed: json['lastExamPassed'] as bool?,
      resetReason: json['resetReason']?.toString(),
      requiredMaterialCount: requiredMaterialCount,
      completedMaterialCount: completedMaterialCount,
      learningProgressPercent:
          (json['learningProgressPercent'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isPassed => verifyStatus == 2;
  bool get canStartExam => learningCompleted && !isPassed;

  String? get resetReasonText {
    switch (resetReason) {
      case 'INACTIVE_180_DAYS':
        return '因长期未接单，您的认证已重置，请重新完成学习与考试。';
      case 'COMPLAINT_OPERATION':
        return '因服务操作不规范被投诉，您的认证已重置，请重新完成学习与考试。';
      default:
        return resetReason == null || resetReason!.isEmpty ? null : resetReason;
    }
  }
}

class TrainingMaterial {
  final int materialId;
  final String title;
  final String content;
  final String materialType;
  final String moduleCode;
  final int sortOrder;
  final int minDurationSeconds;
  final String mediaUrl;
  final int watchedSeconds;
  final bool completed;

  const TrainingMaterial({
    required this.materialId,
    required this.title,
    required this.content,
    this.materialType = 'DOC',
    this.moduleCode = '',
    this.sortOrder = 0,
    this.minDurationSeconds = 60,
    this.mediaUrl = '',
    this.watchedSeconds = 0,
    this.completed = false,
  });

  bool get isVideo => materialType.toUpperCase() == 'VIDEO';

  factory TrainingMaterial.fromJson(Map<String, dynamic> json) {
    return TrainingMaterial(
      materialId: (json['materialId'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      materialType: json['materialType']?.toString() ?? 'DOC',
      moduleCode: json['moduleCode']?.toString() ?? '',
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      minDurationSeconds: (json['minDurationSeconds'] as num?)?.toInt() ?? 60,
      mediaUrl: json['mediaUrl']?.toString() ?? '',
      watchedSeconds: (json['watchedSeconds'] as num?)?.toInt() ?? 0,
      completed: json['completed'] as bool? ?? false,
    );
  }
}

class TrainingCurriculum {
  final int requiredMaterialCount;
  final int completedMaterialCount;
  final int learningProgressPercent;
  final List<TrainingMaterial> materials;

  const TrainingCurriculum({
    required this.requiredMaterialCount,
    required this.completedMaterialCount,
    required this.learningProgressPercent,
    required this.materials,
  });

  bool get allCompleted =>
      requiredMaterialCount > 0 &&
      completedMaterialCount >= requiredMaterialCount;

  factory TrainingCurriculum.fromJson(Map<String, dynamic> json) {
    final list = json['materials'] as List? ?? [];
    return TrainingCurriculum(
      requiredMaterialCount: (json['requiredMaterialCount'] as num?)?.toInt() ?? 0,
      completedMaterialCount: (json['completedMaterialCount'] as num?)?.toInt() ?? 0,
      learningProgressPercent:
          (json['learningProgressPercent'] as num?)?.toInt() ?? 0,
      materials: list
          .map((e) => TrainingMaterial.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList(),
    );
  }
}

class ExamQuestion {
  final int questionId;
  final int questionType;
  final String content;
  final List<String> options;

  const ExamQuestion({
    required this.questionId,
    required this.questionType,
    required this.content,
    required this.options,
  });

  bool get isCore => questionType == 2;

  factory ExamQuestion.fromJson(Map<String, dynamic> json) {
    final opts = json['options'];
    return ExamQuestion(
      questionId: (json['questionId'] as num?)?.toInt() ?? 0,
      questionType: (json['questionType'] as num?)?.toInt() ?? 1,
      content: json['content']?.toString() ?? '',
      options: opts is List ? opts.map((e) => e.toString()).toList() : [],
    );
  }
}

class ExamResult {
  final int score;
  final bool passed;
  final bool corePassed;

  const ExamResult({
    required this.score,
    required this.passed,
    required this.corePassed,
  });

  factory ExamResult.fromJson(Map<String, dynamic> json) {
    return ExamResult(
      score: (json['score'] as num?)?.toInt() ?? 0,
      passed: json['passed'] as bool? ?? false,
      corePassed: json['corePassed'] as bool? ?? false,
    );
  }
}

// ─── DataSource ───────────────────────────────────────────────────────────────

class CaretakerTrainingRemoteDataSource {
  final ApiClient _apiClient;

  const CaretakerTrainingRemoteDataSource(this._apiClient);

  Future<ApiResult<TrainingStatus>> getStatus() async {
    try {
      final response = await _apiClient.post<TrainingStatus>(
        path: '/api/v1/users/training/status',
        dataParser: (data) =>
            TrainingStatus.fromJson(Map<String, dynamic>.from(data as Map)),
      );
      if (!response.isSuccess || response.data == null) {
        return ApiFailure(ApiException(response.message));
      }
      return ApiSuccess(response.data!);
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('获取培训状态失败', cause: e));
    }
  }

  Future<ApiResult<TrainingCurriculum>> getCurriculum() async {
    try {
      final response = await _apiClient.post<TrainingCurriculum>(
        path: '/api/v1/users/training/curriculum',
        dataParser: (data) =>
            TrainingCurriculum.fromJson(Map<String, dynamic>.from(data as Map)),
      );
      if (!response.isSuccess || response.data == null) {
        return ApiFailure(ApiException(response.message));
      }
      return ApiSuccess(response.data!);
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('获取课程列表失败', cause: e));
    }
  }

  Future<ApiResult<TrainingCurriculum>> reportMaterialProgress({
    required int materialId,
    required int watchedSeconds,
  }) async {
    try {
      final response = await _apiClient.post<TrainingCurriculum>(
        path: '/api/v1/users/training/materials/$materialId/progress',
        body: {'watchedSeconds': watchedSeconds},
        dataParser: (data) =>
            TrainingCurriculum.fromJson(Map<String, dynamic>.from(data as Map)),
      );
      if (!response.isSuccess || response.data == null) {
        return ApiFailure(ApiException(response.message));
      }
      return ApiSuccess(response.data!);
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('上报学习进度失败', cause: e));
    }
  }

  Future<ApiResult<void>> completeTraining() async {
    try {
      await _apiClient.post<void>(path: '/api/v1/users/training/complete');
      return const ApiSuccess(null);
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('标记学习完成失败', cause: e));
    }
  }

  Future<ApiResult<List<ExamQuestion>>> startExam() async {
    try {
      final response = await _apiClient.post<List<ExamQuestion>>(
        path: '/api/v1/users/training/exam/start',
        dataParser: (data) {
          final map = Map<String, dynamic>.from(data as Map);
          final list = map['questions'] as List? ?? [];
          return list
              .map((q) =>
                  ExamQuestion.fromJson(Map<String, dynamic>.from(q as Map)))
              .toList();
        },
      );
      if (!response.isSuccess || response.data == null) {
        return ApiFailure(ApiException(response.message));
      }
      return ApiSuccess(response.data!);
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('获取考题失败', cause: e));
    }
  }

  Future<ApiResult<ExamResult>> submitExam(Map<int, String> answers) async {
    try {
      final answerList = answers.entries
          .map((e) => {'questionId': e.key, 'answer': e.value})
          .toList();
      final response = await _apiClient.post<ExamResult>(
        path: '/api/v1/users/training/exam/submit',
        body: {'answers': answerList},
        dataParser: (data) =>
            ExamResult.fromJson(Map<String, dynamic>.from(data as Map)),
      );
      if (!response.isSuccess || response.data == null) {
        return ApiFailure(ApiException(response.message));
      }
      return ApiSuccess(response.data!);
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('提交答案失败', cause: e));
    }
  }
}
