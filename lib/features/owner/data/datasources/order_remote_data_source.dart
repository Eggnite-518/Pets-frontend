import 'package:pets/core/network/api_client.dart';
import 'package:pets/core/network/api_response.dart';

import '../models/create_order_request.dart';
import '../models/create_order_response_model.dart';
import '../models/order_candidate_model.dart';
import '../models/order_payment_page_model.dart';
import '../models/order_quote_request.dart';
import '../models/order_quote_response_model.dart';
import '../models/order_settlement_model.dart';

class OrderRemoteDataSource {
  final ApiClient _apiClient;

  OrderRemoteDataSource(this._apiClient);

  Future<ApiResponse<CreateOrderResponseModel>> createOrder(
    CreateOrderRequest request,
  ) {
    return _apiClient.post<CreateOrderResponseModel>(
      path: '/api/v1/orders',
      body: request.toJson(),
      dataParser: (data) {
        final json = Map<String, dynamic>.from(data as Map);
        return CreateOrderResponseModel.fromJson(json);
      },
    );
  }

  Future<ApiResponse<OrderQuoteResponseModel>> getOrderQuote(
    OrderQuoteRequest request,
  ) {
    return _apiClient.post<OrderQuoteResponseModel>(
      path: '/api/v1/orders/quote',
      body: request.toJson(),
      dataParser: (data) {
        final json = Map<String, dynamic>.from(data as Map);
        return OrderQuoteResponseModel.fromJson(json);
      },
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> getOrderById(String orderId) {
    return _apiClient.get<Map<String, dynamic>>(
      path: '/api/v1/orders/$orderId',
      dataParser: (data) => Map<String, dynamic>.from(data as Map),
    );
  }

  Future<ApiResponse<OrderCandidateListModel>> getOrderCandidates(
    String orderId, {
    String sortBy = 'distance',
  }) {
    return _apiClient.get<OrderCandidateListModel>(
      path: '/api/v1/orders/$orderId/reservations?sortBy=$sortBy',
      dataParser: (data) {
        final json = Map<String, dynamic>.from(data as Map);
        return OrderCandidateListModel.fromJson(json);
      },
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> getProviderDetail(
    String orderId,
    String providerId,
  ) {
    return _apiClient.get<Map<String, dynamic>>(
      path: '/api/v1/orders/$orderId/reservations/$providerId',
      dataParser: (data) => Map<String, dynamic>.from(data as Map),
    );
  }

  Future<ApiResponse<void>> selectProvider(String orderId, String providerId) {
    return _apiClient.post<void>(
      path: '/api/v1/orders/$orderId/reservations/$providerId/selection',
      body: <String, dynamic>{},
    );
  }

  Future<ApiResponse<OrderPaymentPageModel>> createAlipayPagePayment(
    String orderId,
  ) {
    return _apiClient.post<OrderPaymentPageModel>(
      path: '/api/v1/orders/$orderId/payments/alipay/page',
      dataParser: (data) {
        final json = Map<String, dynamic>.from(data as Map);
        return OrderPaymentPageModel.fromJson(json);
      },
    );
  }

  Future<ApiResponse<OrderSettlementModel>> confirmCompletion(String orderId) {
    return _apiClient.post<OrderSettlementModel>(
      path: '/api/v1/orders/$orderId/completion-confirmation',
      body: <String, dynamic>{},
      dataParser: (data) {
        final json = Map<String, dynamic>.from(data as Map);
        return OrderSettlementModel.fromJson(json);
      },
    );
  }

  Future<ApiResponse<void>> confirmExceptionResolved(String orderId) {
    return _apiClient.post<void>(
      path: '/api/v1/orders/$orderId/exception/confirm-resolved',
      body: <String, dynamic>{},
    );
  }

  Future<ApiResponse<OrderSettlementModel>> getSettlement(String orderId) {
    return _apiClient.get<OrderSettlementModel>(
      path: '/api/v1/orders/$orderId/settlement',
      dataParser: (data) {
        final json = Map<String, dynamic>.from(data as Map);
        return OrderSettlementModel.fromJson(json);
      },
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> getFulfillmentRecords(
    String orderId,
  ) {
    return _apiClient.get<Map<String, dynamic>>(
      path: '/api/v1/orders/$orderId/fulfillment-records',
      dataParser: (data) => Map<String, dynamic>.from(data as Map),
    );
  }
}
