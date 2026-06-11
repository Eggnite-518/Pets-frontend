import 'package:pets/core/network/api_client.dart';
import 'package:pets/core/network/api_exception.dart';
import 'package:pets/core/network/api_result.dart';

import '../models/caretaker_review_models.dart';

class CaretakerReviewsRemoteDataSource {
  final ApiClient _apiClient;

  const CaretakerReviewsRemoteDataSource(this._apiClient);

  Future<ApiResult<CaretakerReviewPage>> listReviews({
    int page = 1,
    int pageSize = 10,
    int? reviewStatus,
    bool? lowScoreOnly,
  }) async {
    try {
      final query = <String, String>{'page': '$page', 'pageSize': '$pageSize'};
      if (reviewStatus != null) {
        query['reviewStatus'] = '$reviewStatus';
      }
      if (lowScoreOnly == true) {
        query['lowScoreOnly'] = 'true';
      }

      final queryString = query.entries
          .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
          .join('&');

      final response = await _apiClient.get<CaretakerReviewPage>(
        path: '/api/v1/caretaker/me/reviews?$queryString',
        dataParser: (data) => CaretakerReviewPage.fromJson(
          Map<String, dynamic>.from(data as Map),
        ),
      );
      if (!response.isSuccess || response.data == null) {
        return ApiFailure(ApiException(response.message));
      }
      return ApiSuccess(response.data!);
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('获取评价列表失败', cause: e));
    }
  }

  Future<ApiResult<CaretakerReviewStats>> getStats() async {
    try {
      final response = await _apiClient.get<CaretakerReviewStats>(
        path: '/api/v1/caretaker/me/reviews/stats',
        dataParser: (data) => CaretakerReviewStats.fromJson(
          Map<String, dynamic>.from(data as Map),
        ),
      );
      if (!response.isSuccess || response.data == null) {
        return ApiFailure(ApiException(response.message));
      }
      return ApiSuccess(response.data!);
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('获取评价统计失败', cause: e));
    }
  }

  Future<ApiResult<CaretakerReviewItem>> getReviewDetail(int reviewId) async {
    try {
      final response = await _apiClient.get<CaretakerReviewItem>(
        path: '/api/v1/caretaker/me/reviews/$reviewId',
        dataParser: (data) => CaretakerReviewItem.fromJson(
          Map<String, dynamic>.from(data as Map),
        ),
      );
      if (!response.isSuccess || response.data == null) {
        return ApiFailure(ApiException(response.message));
      }
      return ApiSuccess(response.data!);
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('获取评价详情失败', cause: e));
    }
  }

  Future<ApiResult<ReviewAppealEligibility>> getAppealEligibility(
    int reviewId,
  ) async {
    try {
      final response = await _apiClient.get<ReviewAppealEligibility>(
        path: '/api/v1/caretaker/me/reviews/$reviewId/appeal-eligibility',
        dataParser: (data) => ReviewAppealEligibility.fromJson(
          Map<String, dynamic>.from(data as Map),
        ),
      );
      if (!response.isSuccess || response.data == null) {
        return ApiFailure(ApiException(response.message));
      }
      return ApiSuccess(response.data!);
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('查询申诉资格失败', cause: e));
    }
  }

  Future<ApiResult<ReviewAppealDetail?>> getLatestAppeal(int reviewId) async {
    try {
      final response = await _apiClient.get<ReviewAppealDetail>(
        path: '/api/v1/caretaker/me/reviews/$reviewId/appeals/latest',
        dataParser: (data) =>
            ReviewAppealDetail.fromJson(Map<String, dynamic>.from(data as Map)),
      );
      if (!response.isSuccess) {
        return ApiFailure(ApiException(response.message));
      }
      return ApiSuccess(response.data);
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('获取申诉详情失败', cause: e));
    }
  }

  Future<ApiResult<SubmitReviewAppealResult>> submitAppeal({
    required int reviewId,
    required String reason,
    List<String>? evidenceUrls,
  }) async {
    try {
      final response = await _apiClient.post<SubmitReviewAppealResult>(
        path: '/api/v1/caretaker/me/reviews/$reviewId/appeals',
        body: {
          'reason': reason,
          if (evidenceUrls != null && evidenceUrls.isNotEmpty)
            'evidenceUrls': evidenceUrls,
        },
        dataParser: (data) => SubmitReviewAppealResult.fromJson(
          Map<String, dynamic>.from(data as Map),
        ),
      );
      if (!response.isSuccess || response.data == null) {
        return ApiFailure(ApiException(response.message));
      }
      return ApiSuccess(response.data!);
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('提交申诉失败', cause: e));
    }
  }
}
