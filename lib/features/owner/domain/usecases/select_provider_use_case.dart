import 'package:pets/core/network/api_result.dart';

import '../repositories/order_repository.dart';

class SelectProviderUseCase {
  final OrderRepository _repository;

  SelectProviderUseCase(this._repository);

  Future<ApiResult<void>> call(String orderId, String providerId) {
    return _repository.selectProvider(orderId, providerId);
  }
}
