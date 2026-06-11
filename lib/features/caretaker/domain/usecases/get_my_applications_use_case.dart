import 'package:pets/core/network/api_result.dart';

import '../entities/my_application.dart';
import '../repositories/caretaker_dashboard_repository.dart';

class GetMyApplicationsUseCase {
  final CaretakerDashboardRepository _repository;

  const GetMyApplicationsUseCase(this._repository);

  Future<ApiResult<List<MyApplication>>> call() {
    return _repository.getMyApplications();
  }
}
