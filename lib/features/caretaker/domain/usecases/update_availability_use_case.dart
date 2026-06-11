import 'package:pets/core/network/api_result.dart';

import '../repositories/caretaker_dashboard_repository.dart';

class UpdateAvailabilityUseCase {
  final CaretakerDashboardRepository _repository;

  const UpdateAvailabilityUseCase(this._repository);

  Future<ApiResult<void>> call({required bool isAvailable}) {
    return _repository.updateAvailability(isAvailable: isAvailable);
  }
}
