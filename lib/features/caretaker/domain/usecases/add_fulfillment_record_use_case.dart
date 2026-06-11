import 'dart:io';

import 'package:pets/core/network/api_result.dart';

import '../entities/fulfillment_record.dart';
import '../repositories/fulfillment_repository.dart';

class AddFulfillmentRecordUseCase {
  final FulfillmentRepository _repository;

  const AddFulfillmentRecordUseCase(this._repository);

  Future<ApiResult<FulfillmentRecord>> call({
    required String orderId,
    required int nodeType,
    File? file,
    double? lat,
    double? lng,
  }) {
    return _repository.addFulfillmentRecord(
      orderId: orderId,
      nodeType: nodeType,
      file: file,
      lat: lat,
      lng: lng,
    );
  }
}
