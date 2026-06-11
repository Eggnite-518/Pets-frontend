import 'package:pets/core/network/api_result.dart';

import '../repositories/fulfillment_repository.dart';

class NoFaultRetreatUseCase {
  final FulfillmentRepository _repository;

  const NoFaultRetreatUseCase(this._repository);

  Future<ApiResult<void>> call(String orderId) {
    return _repository.noFaultRetreat(orderId);
  }
}
