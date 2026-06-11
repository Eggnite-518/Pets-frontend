import 'package:pets/core/network/api_result.dart';

import '../entities/order_create_result.dart';
import '../entities/order_candidate.dart';
import '../entities/order_quote.dart';
import '../entities/order_detail.dart';
import '../entities/order_payment_page.dart';
import '../entities/order_settlement.dart';
import '../entities/provider_detail.dart';
import '../../data/models/create_order_request.dart';
import '../../data/models/order_quote_request.dart';

abstract class OrderRepository {
  Future<ApiResult<OrderCreateResult>> createOrder(CreateOrderRequest request);
  Future<ApiResult<OrderQuote>> getOrderQuote(OrderQuoteRequest request);
  Future<ApiResult<OrderDetail>> getOrderById(String orderId);
  Future<ApiResult<OrderCandidateList>> getOrderCandidates(
    String orderId, {
    String sortBy = 'distance',
  });
  Future<ApiResult<ProviderDetail>> getProviderDetail(
    String orderId,
    String providerId,
  );
  Future<ApiResult<void>> selectProvider(String orderId, String providerId);
  Future<ApiResult<OrderPaymentPage>> createOrderAlipayPagePayment(
    String orderId,
  );
  Future<ApiResult<void>> confirmExceptionResolved(String orderId);
  Future<ApiResult<OrderSettlement>> confirmOrderCompletion(String orderId);
  Future<ApiResult<OrderSettlement>> getOrderSettlement(String orderId);
}
