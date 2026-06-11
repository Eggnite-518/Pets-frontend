import 'package:pets/core/network/api_result.dart';

import '../entities/pet_archive.dart';
import '../repositories/pet_archive_repository.dart';

class GetPetArchiveUseCase {
  final PetArchiveRepository _repository;

  const GetPetArchiveUseCase(this._repository);

  Future<ApiResult<PetArchive>> call(int petId) {
    return _repository.getPetArchive(petId);
  }
}
