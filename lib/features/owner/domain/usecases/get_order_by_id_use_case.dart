import 'package:pets/core/network/api_result.dart';

import '../entities/order_detail.dart';
import '../repositories/order_repository.dart';

class GetOrderByIdUseCase {
  final OrderRepository _repository;

  GetOrderByIdUseCase(this._repository);

  Future<ApiResult<OrderDetail>> call(String orderId) {
    return _repository.getOrderById(orderId);
  }
}
