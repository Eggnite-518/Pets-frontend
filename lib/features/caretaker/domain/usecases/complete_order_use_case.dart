import 'package:pets/core/network/api_result.dart';

import '../repositories/fulfillment_repository.dart';

class CompleteOrderUseCase {
  final FulfillmentRepository _repository;

  const CompleteOrderUseCase(this._repository);

  Future<ApiResult<void>> call(String orderId) {
    return _repository.completeOrder(orderId);
  }
}
