import 'package:pets/core/network/api_exception.dart';
import 'package:pets/core/network/api_response_ext.dart';
import 'package:pets/core/network/api_result.dart';

import '../../domain/entities/order_hall_item.dart';
import '../../domain/repositories/order_hall_repository.dart';
import '../datasources/order_hall_remote_data_source.dart';

class OrderHallRepositoryImpl implements OrderHallRepository {
  final OrderHallRemoteDataSource _remoteDataSource;

  const OrderHallRepositoryImpl(this._remoteDataSource);

  @override
  Future<ApiResult<OrderHallPage>> getOrderHall({
    double? caretakerLat,
    double? caretakerLng,
    int? petType,
    int? serviceType,
    double? maxDistanceKm,
    int? minAmount,
    int? maxAmount,
    String? serviceDate,
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final response = await _remoteDataSource.getOrderHall(
        caretakerLat: caretakerLat,
        caretakerLng: caretakerLng,
        petType: petType,
        serviceType: serviceType,
        maxDistanceKm: maxDistanceKm,
        minAmount: minAmount,
        maxAmount: maxAmount,
        serviceDate: serviceDate,
        page: page,
        pageSize: pageSize,
      );
      if (!response.isSuccess) {
        return ApiFailure(ApiException(response.message));
      }
      final data = response.data;
      if (data == null) {
        return const ApiFailure(ApiException('接单大厅数据为空'));
      }
      return ApiSuccess(data);
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('获取接单大厅失败', cause: e));
    }
  }

  @override
  Future<ApiResult<String>> applyOrder(String orderId) async {
    try {
      final response = await _remoteDataSource.applyOrder(orderId);
      if (!response.isSuccess) {
        return ApiFailure(response.toException('报名失败'));
      }
      final applicationId =
          response.data?['applicationId']?.toString() ?? '';
      return ApiSuccess(applicationId);
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('报名失败', cause: e));
    }
  }

  @override
  Future<ApiResult<void>> cancelApplication(String orderId) async {
    try {
      final response = await _remoteDataSource.cancelApplication(orderId);
      if (!response.isSuccess) {
        return ApiFailure(ApiException(response.message));
      }
      return const ApiSuccess(null);
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('取消报名失败', cause: e));
    }
  }
}
