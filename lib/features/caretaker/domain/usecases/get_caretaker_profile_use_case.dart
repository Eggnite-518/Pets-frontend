import 'package:pets/core/network/api_result.dart';

import '../entities/caretaker_profile.dart';
import '../repositories/caretaker_profile_repository.dart';

class GetCaretakerProfileUseCase {
  final CaretakerProfileRepository _repository;

  const GetCaretakerProfileUseCase(this._repository);

  Future<ApiResult<CaretakerProfile>> call() {
    return _repository.getProfile();
  }
}
