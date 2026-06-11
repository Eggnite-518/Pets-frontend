import 'package:pets/core/network/api_result.dart';

import '../entities/order_settlement.dart';
import '../repositories/order_repository.dart';

class ConfirmOrderCompletionUseCase {
  final OrderRepository _repository;

  ConfirmOrderCompletionUseCase(this._repository);

  Future<ApiResult<OrderSettlement>> call(String orderId) {
    return _repository.confirmOrderCompletion(orderId);
  }
}
