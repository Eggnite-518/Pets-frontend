import 'package:pets/core/network/api_result.dart';

import '../repositories/fulfillment_repository.dart';

class SelfReportExceptionUseCase {
  final FulfillmentRepository _repository;

  const SelfReportExceptionUseCase(this._repository);

  Future<ApiResult<void>> call({
    required String orderId,
    required int exceptionType,
    required String description,
  }) {
    return _repository.selfReportException(
      orderId: orderId,
      exceptionType: exceptionType,
      description: description,
    );
  }
}
