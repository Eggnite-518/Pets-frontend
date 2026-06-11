import 'package:pets/core/network/api_result.dart';

import '../entities/caretaker_order_detail.dart';
import '../repositories/caretaker_dashboard_repository.dart';

class GetCaretakerOrderDetailUseCase {
  final CaretakerDashboardRepository _repository;

  const GetCaretakerOrderDetailUseCase(this._repository);

  Future<ApiResult<CaretakerOrderDetail>> call(String orderId) {
    return _repository.getOrderDetail(orderId);
  }
}
