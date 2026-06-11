import 'package:pets/core/network/api_result.dart';

import '../entities/order_settlement.dart';
import '../repositories/order_repository.dart';

class GetOrderSettlementUseCase {
  final OrderRepository _repository;

  GetOrderSettlementUseCase(this._repository);

  Future<ApiResult<OrderSettlement>> call(String orderId) {
    return _repository.getOrderSettlement(orderId);
  }
}
