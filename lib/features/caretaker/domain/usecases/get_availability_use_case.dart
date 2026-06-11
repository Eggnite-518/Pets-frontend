import 'package:pets/core/network/api_result.dart';

import '../repositories/caretaker_dashboard_repository.dart';

class GetAvailabilityUseCase {
  final CaretakerDashboardRepository _repository;

  const GetAvailabilityUseCase(this._repository);

  Future<ApiResult<bool>> call() {
    return _repository.getAvailability();
  }
}
