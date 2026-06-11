import 'package:pets/core/network/api_result.dart';

import '../entities/fulfillment_record.dart';
import '../repositories/fulfillment_repository.dart';

class GetFulfillmentRecordsUseCase {
  final FulfillmentRepository _repository;

  const GetFulfillmentRecordsUseCase(this._repository);

  Future<ApiResult<List<FulfillmentRecord>>> call(String orderId) {
    return _repository.getFulfillmentRecords(orderId);
  }
}
