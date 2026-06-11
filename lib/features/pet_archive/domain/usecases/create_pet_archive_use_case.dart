import 'package:pets/core/network/api_result.dart';

import '../entities/pet_archive.dart';
import '../repositories/pet_archive_repository.dart';
import '../../data/models/create_pet_archive_request.dart';

class CreatePetArchiveUseCase {
  final PetArchiveRepository _repository;

  const CreatePetArchiveUseCase(this._repository);

  Future<ApiResult<PetArchive>> call(CreatePetArchiveRequest request) {
    return _repository.createPetArchive(request);
  }
}
