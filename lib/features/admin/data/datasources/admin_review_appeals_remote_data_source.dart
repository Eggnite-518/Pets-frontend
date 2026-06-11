import 'package:pets/core/network/api_client.dart';
import 'package:pets/core/network/api_exception.dart';
import 'package:pets/core/network/api_result.dart';

import '../models/admin_review_appeal_models.dart';

class AdminReviewAppealsRemoteDataSource {
  final ApiClient _apiClient;

  const AdminReviewAppealsRemoteDataSource(this._apiClient);

  Future<ApiResult<AdminReviewAppealPage>> listAppeals({
    int page = 1,
    int pageSize = 20,
    int? appealStatus,
  }) async {
    try {
      final query = <String, String>{'page': '$page', 'pageSize': '$pageSize'};
      if (appealStatus != null) {
        query['appealStatus'] = '$appealStatus';
      }
      final queryString = query.entries
          .map((entry) => '${entry.key}=${Uri.encodeQueryComponent(entry.value)}')
          .join('&');

      final response = await _apiClient.get<AdminReviewAppealPage>(
        path: '/api/v1/admin/reviews/appeals?$queryString',
        dataParser: (data) => AdminReviewAppealPage.fromJson(
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
      return ApiFailure(ApiException('获取申诉列表失败', cause: e));
    }
  }

  Future<ApiResult<AdminReviewAppealItem>> getAppealDetail(int appealId) async {
    try {
      final response = await _apiClient.get<AdminReviewAppealItem>(
        path: '/api/v1/admin/reviews/appeals/$appealId',
        dataParser: (data) => AdminReviewAppealItem.fromJson(
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
      return ApiFailure(ApiException('获取申诉详情失败', cause: e));
    }
  }

  Future<ApiResult<AdminOrderEvidenceChain>> getOrderEvidence(int orderId) async {
    try {
      final response = await _apiClient.get<AdminOrderEvidenceChain>(
        path: '/api/v1/admin/orders/$orderId/evidence',
        dataParser: (data) => AdminOrderEvidenceChain.fromJson(
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
      return ApiFailure(ApiException('获取订单证据链失败', cause: e));
    }
  }

  Future<ApiResult<void>> updateAppealStatus({
    required int appealId,
    required int appealStatus,
    required String adminMemo,
  }) async {
    try {
      final response = await _apiClient.post<void>(
        path: '/api/v1/admin/reviews/appeals/$appealId/status',
        body: {'appealStatus': appealStatus, 'adminMemo': adminMemo},
      );
      if (!response.isSuccess) {
        return ApiFailure(ApiException(response.message));
      }
      return const ApiSuccess(null);
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('更新申诉状态失败', cause: e));
    }
  }
}
