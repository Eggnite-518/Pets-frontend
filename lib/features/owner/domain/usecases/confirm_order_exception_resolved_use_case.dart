import 'package:pets/core/network/api_result.dart';

import '../repositories/order_repository.dart';

class ConfirmOrderExceptionResolvedUseCase {
  final OrderRepository _repository;

  ConfirmOrderExceptionResolvedUseCase(this._repository);

  Future<ApiResult<void>> call(String orderId) {
    return _repository.confirmExceptionResolved(orderId);
  }
}
