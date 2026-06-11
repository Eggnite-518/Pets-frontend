import 'package:pets/core/network/api_result.dart';

import '../entities/active_order.dart';
import '../repositories/caretaker_dashboard_repository.dart';

class GetActiveOrdersUseCase {
  final CaretakerDashboardRepository _repository;

  const GetActiveOrdersUseCase(this._repository);

  Future<ApiResult<List<ActiveOrder>>> call() {
    return _repository.getActiveOrders();
  }
}
