import 'package:pets/core/network/api_result.dart';

import '../entities/pet_archive.dart';
import '../../data/models/create_pet_archive_request.dart';

abstract class PetArchiveRepository {
  Future<ApiResult<PetArchive>> createPetArchive(
    CreatePetArchiveRequest request,
  );

  Future<ApiResult<PetArchive>> getPetArchive(int petId);

  Future<ApiResult<PetArchive>> updatePetArchive({
    required int petId,
    required CreatePetArchiveRequest request,
  });

  Future<ApiResult<void>> deletePetArchive(int petId);
}
