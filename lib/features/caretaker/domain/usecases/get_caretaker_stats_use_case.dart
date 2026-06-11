import 'package:pets/core/network/api_result.dart';

import '../entities/caretaker_stats.dart';
import '../repositories/caretaker_dashboard_repository.dart';

class GetCaretakerStatsUseCase {
  final CaretakerDashboardRepository _repository;

  const GetCaretakerStatsUseCase(this._repository);

  Future<ApiResult<CaretakerStats>> call() {
    return _repository.getStats();
  }
}
