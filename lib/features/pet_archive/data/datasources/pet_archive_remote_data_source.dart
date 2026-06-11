import 'package:pets/core/network/api_client.dart';
import 'package:pets/core/network/api_response.dart';

import '../models/create_pet_archive_request.dart';
import '../models/pet_archive_model.dart';

class PetArchiveRemoteDataSource {
  final ApiClient _apiClient;

  PetArchiveRemoteDataSource(this._apiClient);

  Future<ApiResponse<PetArchiveModel>> createPetArchive(
    CreatePetArchiveRequest request,
  ) {
    return _apiClient.post<PetArchiveModel>(
      path: '/api/v1/pet-archives',
      body: request.toJson(),
      dataParser: _parseModel,
    );
  }

  Future<ApiResponse<PetArchiveModel>> getPetArchive(int petId) {
    return _apiClient.get<PetArchiveModel>(
      path: '/api/v1/pet-archives/$petId',
      dataParser: _parseModel,
    );
  }

  Future<ApiResponse<PetArchiveModel>> updatePetArchive({
    required int petId,
    required CreatePetArchiveRequest request,
  }) {
    return _apiClient.put<PetArchiveModel>(
      path: '/api/v1/pet-archives/$petId',
      body: request.toJson(),
      dataParser: _parseModel,
    );
  }

  Future<ApiResponse<void>> deletePetArchive(int petId) {
    return _apiClient.delete<void>(
      path: '/api/v1/pet-archives/$petId',
    );
  }

  static PetArchiveModel _parseModel(Object? data) {
    final json = Map<String, dynamic>.from(data as Map);
    return PetArchiveModel.fromJson(json);
  }
}
