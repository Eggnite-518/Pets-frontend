import 'package:pets/core/network/api_exception.dart';
import 'package:pets/core/network/api_result.dart';

import '../../domain/entities/order_create_result.dart';
import '../../domain/entities/order_candidate.dart';
import '../../domain/entities/order_quote.dart';
import '../../domain/entities/order_detail.dart';
import '../../domain/entities/order_payment_page.dart';
import '../../domain/entities/order_settlement.dart';
import '../../domain/entities/provider_detail.dart';
import '../../domain/repositories/order_repository.dart';
import '../datasources/order_remote_data_source.dart';
import '../models/create_order_request.dart';
import '../models/order_quote_request.dart';
import '../models/order_detail_model.dart';
import '../models/provider_detail_model.dart';

class OrderRepositoryImpl implements OrderRepository {
  final OrderRemoteDataSource _remoteDataSource;

  OrderRepositoryImpl(this._remoteDataSource);

  @override
  Future<ApiResult<OrderCreateResult>> createOrder(
    CreateOrderRequest request,
  ) async {
    try {
      final response = await _remoteDataSource.createOrder(request);
      final order = response.data;
      if (order == null) {
        return const ApiFailure<OrderCreateResult>(
          ApiException('Backend did not return order data'),
        );
      }
      return ApiSuccess<OrderCreateResult>(order.toEntity());
    } on ApiException catch (error) {
      return ApiFailure<OrderCreateResult>(error);
    } catch (error) {
      return ApiFailure<OrderCreateResult>(
        ApiException('Failed to create order', cause: error),
      );
    }
  }

  @override
  Future<ApiResult<OrderQuote>> getOrderQuote(OrderQuoteRequest request) async {
    try {
      final response = await _remoteDataSource.getOrderQuote(request);
      final quote = response.data;
      if (quote == null) {
        return const ApiFailure<OrderQuote>(
          ApiException('Backend did not return quote data'),
        );
      }
      return ApiSuccess<OrderQuote>(quote.toEntity());
    } on ApiException catch (error) {
      return ApiFailure<OrderQuote>(error);
    } catch (error) {
      return ApiFailure<OrderQuote>(
        ApiException('Failed to fetch quote', cause: error),
      );
    }
  }

  @override
  Future<ApiResult<OrderDetail>> getOrderById(String orderId) async {
    try {
      final response = await _remoteDataSource.getOrderById(orderId);
      final json = response.data;
      if (json == null) {
        return const ApiFailure<OrderDetail>(
          ApiException('Backend did not return order detail'),
        );
      }
      final model = OrderDetailModel.fromJson(json);
      return ApiSuccess<OrderDetail>(model);
    } on ApiException catch (error) {
      return ApiFailure<OrderDetail>(error);
    } catch (error) {
      return ApiFailure<OrderDetail>(
        ApiException('Failed to fetch order detail', cause: error),
      );
    }
  }

  @override
  Future<ApiResult<OrderCandidateList>> getOrderCandidates(
    String orderId, {
    String sortBy = 'distance',
  }) async {
    try {
      final response = await _remoteDataSource.getOrderCandidates(
        orderId,
        sortBy: sortBy,
      );
      final model = response.data;
      if (model == null) {
        return const ApiFailure<OrderCandidateList>(
          ApiException('Backend did not return candidates'),
        );
      }
      return ApiSuccess<OrderCandidateList>(model);
    } on ApiException catch (error) {
      return ApiFailure<OrderCandidateList>(error);
    } catch (error) {
      return ApiFailure<OrderCandidateList>(
        ApiException('Failed to fetch candidates', cause: error),
      );
    }
  }

  @override
  Future<ApiResult<ProviderDetail>> getProviderDetail(
    String orderId,
    String providerId,
  ) async {
    try {
      final response = await _remoteDataSource.getProviderDetail(
        orderId,
        providerId,
      );
      final json = response.data;
      if (json == null) {
        return const ApiFailure<ProviderDetail>(
          ApiException('Backend did not return provider detail'),
        );
      }
      final model = ProviderDetailModel.fromJson(json);
      return ApiSuccess<ProviderDetail>(model);
    } on ApiException catch (error) {
      return ApiFailure<ProviderDetail>(error);
    } catch (error) {
      return ApiFailure<ProviderDetail>(
        ApiException('Failed to fetch provider detail', cause: error),
      );
    }
  }

  @override
  Future<ApiResult<void>> selectProvider(
    String orderId,
    String providerId,
  ) async {
    try {
      final response = await _remoteDataSource.selectProvider(
        orderId,
        providerId,
      );
      if (!response.isSuccess) {
        return ApiFailure<void>(ApiException(response.message));
      }
      return const ApiSuccess<void>(null);
    } on ApiException catch (error) {
      return ApiFailure<void>(error);
    } catch (error) {
      return ApiFailure<void>(
        ApiException('Failed to select provider', cause: error),
      );
    }
  }

  @override
  Future<ApiResult<OrderPaymentPage>> createOrderAlipayPagePayment(
    String orderId,
  ) async {
    try {
      final response = await _remoteDataSource.createAlipayPagePayment(orderId);
      final payment = response.data;
      if (payment == null) {
        return const ApiFailure<OrderPaymentPage>(
          ApiException('Backend did not return payment payload'),
        );
      }
      return ApiSuccess<OrderPaymentPage>(payment);
    } on ApiException catch (error) {
      return ApiFailure<OrderPaymentPage>(error);
    } catch (error) {
      return ApiFailure<OrderPaymentPage>(
        ApiException('Failed to create order payment', cause: error),
      );
    }
  }

  @override
  Future<ApiResult<void>> confirmExceptionResolved(String orderId) async {
    try {
      final response = await _remoteDataSource.confirmExceptionResolved(
        orderId,
      );
      if (!response.isSuccess) {
        return ApiFailure<void>(ApiException(response.message));
      }
      return const ApiSuccess<void>(null);
    } on ApiException catch (error) {
      return ApiFailure<void>(error);
    } catch (error) {
      return ApiFailure<void>(
        ApiException('Failed to confirm exception resolved', cause: error),
      );
    }
  }

  @override
  Future<ApiResult<OrderSettlement>> confirmOrderCompletion(
    String orderId,
  ) async {
    try {
      final response = await _remoteDataSource.confirmCompletion(orderId);
      if (!response.isSuccess) {
        return ApiFailure<OrderSettlement>(
          ApiException(
            response.message.isNotEmpty ? response.message : '确认结算失败',
          ),
        );
      }
      final settlement = response.data;
      if (settlement == null) {
        return const ApiFailure<OrderSettlement>(
          ApiException('结算成功但未返回明细，请刷新订单查看'),
        );
      }
      return ApiSuccess<OrderSettlement>(settlement);
    } on ApiException catch (error) {
      return ApiFailure<OrderSettlement>(error);
    } catch (error) {
      return ApiFailure<OrderSettlement>(
        ApiException('Failed to confirm order completion', cause: error),
      );
    }
  }

  @override
  Future<ApiResult<OrderSettlement>> getOrderSettlement(String orderId) async {
    try {
      final response = await _remoteDataSource.getSettlement(orderId);
      if (!response.isSuccess) {
        return ApiFailure<OrderSettlement>(
          ApiException(
            response.message.isNotEmpty ? response.message : '获取结算信息失败',
          ),
        );
      }
      final settlement = response.data;
      if (settlement == null) {
        return const ApiFailure<OrderSettlement>(ApiException('暂无结算信息'));
      }
      return ApiSuccess<OrderSettlement>(settlement);
    } on ApiException catch (error) {
      return ApiFailure<OrderSettlement>(error);
    } catch (error) {
      return ApiFailure<OrderSettlement>(
        ApiException('获取结算信息失败', cause: error),
      );
    }
  }
}
