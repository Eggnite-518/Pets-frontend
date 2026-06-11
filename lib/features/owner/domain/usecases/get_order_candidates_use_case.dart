import 'package:pets/core/network/api_result.dart';

import '../entities/order_candidate.dart';
import '../repositories/order_repository.dart';

class GetOrderCandidatesUseCase {
  final OrderRepository _repository;

  GetOrderCandidatesUseCase(this._repository);

  Future<ApiResult<OrderCandidateList>> call(
    String orderId, {
    String sortBy = 'distance',
  }) {
    return _repository.getOrderCandidates(orderId, sortBy: sortBy);
  }
}
