import 'dart:io';

import 'package:pets/core/network/api_result.dart';

import '../entities/fulfillment_record.dart';

abstract class FulfillmentRepository {
  Future<ApiResult<FulfillmentRecord>> addFulfillmentRecord({
    required String orderId,
    required int nodeType,
    File? file,
    double? lat,
    double? lng,
  });

  Future<ApiResult<void>> completeOrder(String orderId);

  Future<ApiResult<List<FulfillmentRecord>>> getFulfillmentRecords(
    String orderId,
  );

  Future<ApiResult<void>> selfReportException({
    required String orderId,
    required int exceptionType,
    required String description,
  });

  Future<ApiResult<void>> noFaultRetreat(String orderId);
}
