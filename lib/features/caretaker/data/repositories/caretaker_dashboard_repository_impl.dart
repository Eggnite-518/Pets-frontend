import 'dart:developer' as dev;

import 'package:pets/core/network/api_exception.dart';
import 'package:pets/core/network/api_result.dart';

import '../../domain/entities/active_order.dart';
import '../../domain/entities/caretaker_order_detail.dart';
import '../../domain/entities/caretaker_stats.dart';
import '../../domain/entities/my_application.dart';
import '../../domain/repositories/caretaker_dashboard_repository.dart';
import '../datasources/caretaker_dashboard_remote_data_source.dart';

class CaretakerDashboardRepositoryImpl implements CaretakerDashboardRepository {
  final CaretakerDashboardRemoteDataSource _remoteDataSource;

  const CaretakerDashboardRepositoryImpl(this._remoteDataSource);

  @override
  Future<ApiResult<List<MyApplication>>> getMyApplications() async {
    try {
      final response = await _remoteDataSource.getMyApplications();
      if (!response.isSuccess) {
        return ApiFailure(ApiException(response.message));
      }
      final list = response.data ?? [];
      return ApiSuccess(list.map((m) => m.toEntity()).toList());
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('获取报名列表失败', cause: e));
    }
  }

  @override
  Future<ApiResult<List<ActiveOrder>>> getActiveOrders() async {
    try {
      final response = await _remoteDataSource.getActiveOrders();
      if (!response.isSuccess) {
        return ApiFailure(ApiException(response.message));
      }
      final list = response.data ?? [];
      return ApiSuccess(list.map((m) => m.toEntity()).toList());
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('获取履约中订单失败', cause: e));
    }
  }

  @override
  Future<ApiResult<List<ActiveOrder>>> getPendingConfirmationOrders() async {
    try {
      final response = await _remoteDataSource.getPendingConfirmationOrders();
      if (!response.isSuccess) {
        return ApiFailure(ApiException(response.message));
      }
      final list = response.data ?? [];
      return ApiSuccess(list.map((m) => m.toEntity()).toList());
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('获取等待确认订单失败', cause: e));
    }
  }

  @override
  Future<ApiResult<List<ActiveOrder>>> getTodayCompletedOrders() async {
    try {
      final response = await _remoteDataSource.getTodayCompletedOrders();
      if (!response.isSuccess) {
        return ApiFailure(ApiException(response.message));
      }
      final list = response.data ?? [];
      return ApiSuccess(list.map((m) => m.toEntity()).toList());
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('获取今日完成订单失败', cause: e));
    }
  }

  @override
  static const _kEmptyStats = CaretakerStats(
    todayOrderCount: 0,
    creditScore: 0,
    pendingPaymentCount: 0,
  );

  Future<ApiResult<CaretakerStats>> getStats() async {
    try {
      final response = await _remoteDataSource.getStats();
      if (!response.isSuccess) {
        return ApiFailure(ApiException(response.message));
      }
      final data = response.data;
      // data 为 null 表示新用户还没有统计数据，按全 0 处理
      if (data == null) {
        dev.log('[Stats] data is null, returning empty stats', name: 'Dashboard');
        return const ApiSuccess(_kEmptyStats);
      }
      return ApiSuccess(data.toEntity());
    } on ApiException catch (e) {
      dev.log('[Stats] ApiException: ${e.message} | statusCode=${e.statusCode} | cause=${e.cause}', name: 'Dashboard');
      return ApiFailure(e);
    } catch (e, st) {
      dev.log('[Stats] Unknown error: $e', name: 'Dashboard', stackTrace: st);
      return ApiFailure(ApiException('获取工作台统计失败', cause: e));
    }
  }

  @override
  Future<ApiResult<bool>> getAvailability() async {
    try {
      final response = await _remoteDataSource.getAvailability();
      final isAvailable = response.data?['isAvailable'] == true;
      return ApiSuccess(isAvailable);
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('获取接单状态失败', cause: e));
    }
  }

  @override
  Future<ApiResult<void>> updateAvailability({required bool isAvailable}) async {
    try {
      await _remoteDataSource.updateAvailability(isAvailable: isAvailable);
      return const ApiSuccess(null);
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('更新接单状态失败', cause: e));
    }
  }

  @override
  Future<ApiResult<CaretakerOrderDetail>> getOrderDetail(String orderId) async {
    try {
      final response = await _remoteDataSource.getOrderDetail(orderId);
      if (!response.isSuccess) {
        return ApiFailure(ApiException(response.message));
      }
      final data = response.data;
      if (data == null) {
        return const ApiFailure(ApiException('订单详情为空'));
      }
      return ApiSuccess(data.toEntity());
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('获取订单详情失败', cause: e));
    }
  }
}
