import 'dart:io';

import 'package:pets/core/network/api_exception.dart';
import 'package:pets/core/network/api_result.dart';

import '../../domain/entities/fulfillment_record.dart';
import '../../domain/repositories/fulfillment_repository.dart';
import '../datasources/fulfillment_remote_data_source.dart';

class FulfillmentRepositoryImpl implements FulfillmentRepository {
  final FulfillmentRemoteDataSource _remoteDataSource;

  const FulfillmentRepositoryImpl(this._remoteDataSource);

  @override
  Future<ApiResult<FulfillmentRecord>> addFulfillmentRecord({
    required String orderId,
    required int nodeType,
    File? file,
    double? lat,
    double? lng,
  }) async {
    try {
      final response = await _remoteDataSource.addFulfillmentRecord(
        orderId: orderId,
        nodeType: nodeType,
        file: file,
        lat: lat,
        lng: lng,
      );
      if (!response.isSuccess) {
        return ApiFailure(
          ApiException(
            response.message.isNotEmpty ? response.message : '提交履约记录失败',
            businessCode: response.code?.toString(),
          ),
        );
      }
      final record = response.data;
      if (record == null) {
        return const ApiFailure(ApiException('后端未返回履约记录，请稍后重试'));
      }
      return ApiSuccess(record);
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('提交履约记录失败', cause: e));
    }
  }

  @override
  Future<ApiResult<void>> completeOrder(String orderId) async {
    try {
      await _remoteDataSource.completeOrder(orderId);
      return const ApiSuccess(null);
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('完成服务失败', cause: e));
    }
  }

  @override
  Future<ApiResult<List<FulfillmentRecord>>> getFulfillmentRecords(
    String orderId,
  ) async {
    try {
      final response = await _remoteDataSource.getFulfillmentRecords(orderId);
      return ApiSuccess(response.data ?? []);
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('获取履约记录失败', cause: e));
    }
  }

  @override
  Future<ApiResult<void>> selfReportException({
    required String orderId,
    required int exceptionType,
    required String description,
  }) async {
    try {
      await _remoteDataSource.selfReportException(
        orderId: orderId,
        exceptionType: exceptionType,
        description: description,
      );
      return const ApiSuccess(null);
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('提交紧急求助失败', cause: e));
    }
  }

  @override
  Future<ApiResult<void>> noFaultRetreat(String orderId) async {
    try {
      await _remoteDataSource.noFaultRetreat(orderId);
      return const ApiSuccess(null);
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('申请无责撤退失败', cause: e));
    }
  }
}
