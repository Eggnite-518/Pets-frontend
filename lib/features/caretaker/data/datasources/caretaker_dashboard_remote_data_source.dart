import 'package:pets/core/network/api_client.dart';
import 'package:pets/core/network/api_response.dart';

import '../models/active_order_model.dart';
import '../models/caretaker_order_detail_model.dart';
import '../models/caretaker_stats_model.dart';
import '../models/my_application_model.dart';

class CaretakerDashboardRemoteDataSource {
  final ApiClient _apiClient;

  const CaretakerDashboardRemoteDataSource(this._apiClient);

  Future<ApiResponse<List<MyApplicationModel>>> getMyApplications() {
    return _apiClient.get<List<MyApplicationModel>>(
      path: '/api/v1/caretaker/me/applications',
      dataParser: (data) {
        final list = data as List;
        return list
            .map((e) => MyApplicationModel.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<ApiResponse<List<ActiveOrderModel>>> getActiveOrders() {
    return _apiClient.get<List<ActiveOrderModel>>(
      path: '/api/v1/caretaker/me/orders/active',
      dataParser: (data) {
        final list = data as List;
        return list
            .map((e) => ActiveOrderModel.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<ApiResponse<List<ActiveOrderModel>>> getPendingConfirmationOrders() {
    return _apiClient.get<List<ActiveOrderModel>>(
      path: '/api/v1/caretaker/me/orders/pending-confirmation',
      dataParser: (data) {
        final list = data as List;
        return list
            .map((e) => ActiveOrderModel.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<ApiResponse<List<ActiveOrderModel>>> getTodayCompletedOrders() {
    return _apiClient.get<List<ActiveOrderModel>>(
      path: '/api/v1/caretaker/me/orders/today-completed',
      dataParser: (data) {
        final list = data as List;
        return list
            .map((e) => ActiveOrderModel.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<ApiResponse<CaretakerStatsModel>> getStats() {
    return _apiClient.get<CaretakerStatsModel>(
      path: '/api/v1/caretaker/me/stats',
      dataParser: (data) {
        final json = Map<String, dynamic>.from(data as Map);
        return CaretakerStatsModel.fromJson(json);
      },
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> getAvailability() {
    return _apiClient.get<Map<String, dynamic>>(
      path: '/api/v1/caretaker/me/availability',
      dataParser: (data) => Map<String, dynamic>.from(data as Map),
    );
  }

  Future<ApiResponse<void>> updateAvailability({required bool isAvailable}) {
    return _apiClient.put<void>(
      path: '/api/v1/caretaker/me/availability',
      body: {'isAvailable': isAvailable},
    );
  }

  /// API-21 获取履约订单详情
  Future<ApiResponse<CaretakerOrderDetailModel>> getOrderDetail(
      String orderId) {
    return _apiClient.get<CaretakerOrderDetailModel>(
      path: '/api/v1/caretaker/orders/$orderId',
      dataParser: (data) {
        final json = Map<String, dynamic>.from(data as Map);
        return CaretakerOrderDetailModel.fromJson(json);
      },
    );
  }
}
