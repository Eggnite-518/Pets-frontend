import 'package:pets/core/network/api_result.dart';

import '../repositories/order_hall_repository.dart';

class CancelApplicationUseCase {
  final OrderHallRepository _repository;

  const CancelApplicationUseCase(this._repository);

  Future<ApiResult<void>> call(String orderId) {
    return _repository.cancelApplication(orderId);
  }
}
