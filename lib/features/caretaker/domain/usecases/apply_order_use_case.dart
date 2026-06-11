import 'package:pets/core/network/api_result.dart';

import '../repositories/order_hall_repository.dart';

class ApplyOrderUseCase {
  final OrderHallRepository _repository;

  const ApplyOrderUseCase(this._repository);

  Future<ApiResult<String>> call(String orderId) {
    return _repository.applyOrder(orderId);
  }
}
