import 'package:pets/core/network/api_client.dart';
import 'package:pets/core/network/api_exception.dart';
import 'package:pets/core/network/api_result.dart';

import '../models/order_dispute_models.dart';

class OrderDisputeRemoteDataSource {
  final ApiClient _apiClient;

  const OrderDisputeRemoteDataSource(this._apiClient);

  Future<ApiResult<List<OrderDisputeItem>>> listDisputes(String orderId) async {
    try {
      final response = await _apiClient.get<List<OrderDisputeItem>>(
        path: '/api/v1/orders/$orderId/disputes',
        dataParser: (data) {
          final items = data as List? ?? [];
          return items
              .whereType<Map>()
              .map((item) => OrderDisputeItem.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        },
      );
      if (!response.isSuccess) {
        return ApiFailure(ApiException(response.message));
      }
      return ApiSuccess(response.data ?? const []);
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('获取申诉记录失败', cause: e));
    }
  }

  Future<ApiResult<OrderEvidenceChain>> getEvidence(String orderId) async {
    try {
      final response = await _apiClient.get<OrderEvidenceChain>(
        path: '/api/v1/orders/$orderId/evidence',
        dataParser: (data) => OrderEvidenceChain.fromJson(
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
      return ApiFailure(ApiException('获取争议证据链失败', cause: e));
    }
  }

  Future<ApiResult<SubmitOrderDisputeResult>> submitDispute({
    required String orderId,
    required int disputeType,
    required String reason,
    List<String>? evidenceUrls,
  }) async {
    try {
      final response = await _apiClient.post<SubmitOrderDisputeResult>(
        path: '/api/v1/orders/$orderId/disputes',
        body: {
          'disputeType': disputeType,
          'reason': reason,
          if (evidenceUrls != null && evidenceUrls.isNotEmpty)
            'evidenceUrls': evidenceUrls,
        },
        dataParser: (data) => SubmitOrderDisputeResult.fromJson(
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
