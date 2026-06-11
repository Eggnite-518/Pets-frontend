import 'package:pets/core/network/api_result.dart';

import '../entities/provider_detail.dart';
import '../repositories/order_repository.dart';

class GetProviderDetailUseCase {
  final OrderRepository _repository;

  GetProviderDetailUseCase(this._repository);

  Future<ApiResult<ProviderDetail>> call(String orderId, String providerId) {
    return _repository.getProviderDetail(orderId, providerId);
  }
}
