import 'package:pets/core/network/api_exception.dart';
import 'package:pets/core/network/api_response.dart';
import 'package:pets/core/network/api_result.dart';

import '../../domain/entities/pet_archive.dart';
import '../../domain/repositories/pet_archive_repository.dart';
import '../datasources/pet_archive_remote_data_source.dart';
import '../models/create_pet_archive_request.dart';
import '../models/pet_archive_model.dart';

class PetArchiveRepositoryImpl implements PetArchiveRepository {
  final PetArchiveRemoteDataSource _remoteDataSource;

  PetArchiveRepositoryImpl(this._remoteDataSource);

  @override
  Future<ApiResult<PetArchive>> createPetArchive(
    CreatePetArchiveRequest request,
  ) async {
    return _mapResponse(
      () => _remoteDataSource.createPetArchive(request),
      'Failed to create pet archive',
    );
  }

  @override
  Future<ApiResult<PetArchive>> getPetArchive(int petId) async {
    return _mapResponse(
      () => _remoteDataSource.getPetArchive(petId),
      'Failed to load pet archive',
    );
  }

  @override
  Future<ApiResult<PetArchive>> updatePetArchive({
    required int petId,
    required CreatePetArchiveRequest request,
  }) async {
    return _mapResponse(
      () => _remoteDataSource.updatePetArchive(petId: petId, request: request),
      'Failed to update pet archive',
    );
  }

  @override
  Future<ApiResult<void>> deletePetArchive(int petId) async {
    try {
      final response = await _remoteDataSource.deletePetArchive(petId);
      if (!response.isSuccess) {
        return ApiFailure<void>(ApiException(response.message));
      }
      return const ApiSuccess<void>(null);
    } on ApiException catch (error) {
      return ApiFailure<void>(error);
    } catch (error) {
      return ApiFailure<void>(
        ApiException('Failed to delete pet archive', cause: error),
      );
    }
  }

  Future<ApiResult<PetArchive>> _mapResponse(
    Future<ApiResponse<PetArchiveModel>> Function() request,
    String fallbackMessage,
  ) async {
    try {
      final response = await request();
      final petArchive = response.data;
      if (petArchive == null) {
        return ApiFailure<PetArchive>(
          ApiException('Backend did not return pet archive data'),
        );
      }
      return ApiSuccess<PetArchive>(petArchive.toEntity());
    } on ApiException catch (error) {
      return ApiFailure<PetArchive>(error);
    } catch (error) {
      return ApiFailure<PetArchive>(
        ApiException(fallbackMessage, cause: error),
      );
    }
  }
}
