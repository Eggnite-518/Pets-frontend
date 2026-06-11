import 'package:pets/core/network/api_result.dart';

import '../entities/active_order.dart';
import '../entities/caretaker_order_detail.dart';
import '../entities/caretaker_stats.dart';
import '../entities/my_application.dart';

abstract class CaretakerDashboardRepository {
  Future<ApiResult<List<MyApplication>>> getMyApplications();

  Future<ApiResult<List<ActiveOrder>>> getActiveOrders();

  Future<ApiResult<List<ActiveOrder>>> getPendingConfirmationOrders();

  Future<ApiResult<List<ActiveOrder>>> getTodayCompletedOrders();

  Future<ApiResult<CaretakerStats>> getStats();

  Future<ApiResult<bool>> getAvailability();

  Future<ApiResult<void>> updateAvailability({required bool isAvailable});

  Future<ApiResult<CaretakerOrderDetail>> getOrderDetail(String orderId);
}
