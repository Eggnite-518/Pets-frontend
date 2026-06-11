import 'package:pets/core/network/api_result.dart';

import '../entities/order_quote.dart';
import '../repositories/order_repository.dart';
import '../../data/models/order_quote_request.dart';

class GetOrderQuoteUseCase {
  final OrderRepository _repository;

  const GetOrderQuoteUseCase(this._repository);

  Future<ApiResult<OrderQuote>> call(OrderQuoteRequest request) {
    return _repository.getOrderQuote(request);
  }
}
