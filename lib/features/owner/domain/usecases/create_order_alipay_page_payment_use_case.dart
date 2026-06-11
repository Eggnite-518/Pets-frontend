import 'package:pets/core/network/api_result.dart';

import '../entities/order_payment_page.dart';
import '../repositories/order_repository.dart';

class CreateOrderAlipayPagePaymentUseCase {
  final OrderRepository _repository;

  CreateOrderAlipayPagePaymentUseCase(this._repository);

  Future<ApiResult<OrderPaymentPage>> call(String orderId) {
    return _repository.createOrderAlipayPagePayment(orderId);
  }
}
