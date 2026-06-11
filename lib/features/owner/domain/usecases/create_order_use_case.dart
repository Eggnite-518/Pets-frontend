import 'package:pets/core/network/api_result.dart';

import '../entities/order_create_result.dart';
import '../repositories/order_repository.dart';
import '../../data/models/create_order_request.dart';

class CreateOrderUseCase {
  final OrderRepository _repository;

  const CreateOrderUseCase(this._repository);

  Future<ApiResult<OrderCreateResult>> call(CreateOrderRequest request) {
    return _repository.createOrder(request);
  }
}
