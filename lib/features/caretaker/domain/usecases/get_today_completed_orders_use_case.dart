import 'package:pets/core/network/api_result.dart';

import '../entities/active_order.dart';
import '../repositories/caretaker_dashboard_repository.dart';

class GetTodayCompletedOrdersUseCase {
  final CaretakerDashboardRepository _repository;

  const GetTodayCompletedOrdersUseCase(this._repository);

  Future<ApiResult<List<ActiveOrder>>> call() {
    return _repository.getTodayCompletedOrders();
  }
}
