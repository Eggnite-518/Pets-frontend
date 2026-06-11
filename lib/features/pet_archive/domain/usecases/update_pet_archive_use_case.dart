import 'package:pets/core/network/api_result.dart';

import '../entities/pet_archive.dart';
import '../repositories/pet_archive_repository.dart';
import '../../data/models/create_pet_archive_request.dart';

class UpdatePetArchiveUseCase {
  final PetArchiveRepository _repository;

  const UpdatePetArchiveUseCase(this._repository);

  Future<ApiResult<PetArchive>> call({
    required int petId,
    required CreatePetArchiveRequest request,
  }) {
    return _repository.updatePetArchive(petId: petId, request: request);
  }
}
