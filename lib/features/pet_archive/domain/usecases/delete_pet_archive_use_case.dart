import 'package:pets/core/network/api_result.dart';

import '../repositories/pet_archive_repository.dart';

class DeletePetArchiveUseCase {
  final PetArchiveRepository _repository;

  const DeletePetArchiveUseCase(this._repository);

  Future<ApiResult<void>> call(int petId) {
    return _repository.deletePetArchive(petId);
  }
}
