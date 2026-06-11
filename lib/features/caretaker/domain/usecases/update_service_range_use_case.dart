import 'package:pets/core/network/api_result.dart';

import '../repositories/caretaker_profile_repository.dart';

/// 更新宠托师档案
/// 后端要求 nickname / avatarUrl / certLabels / serviceRangeKm 四个字段必传；
/// residentAddress / residentLatitude / residentLongitude 可选。
class UpdateProfileUseCase {
  final CaretakerProfileRepository _repository;

  const UpdateProfileUseCase(this._repository);

  Future<ApiResult<void>> call({
    required String nickname,
    required String avatarUrl,
    required List<String> certLabels,
    required int serviceRangeKm,
    String? residentAddress,
    double? residentLatitude,
    double? residentLongitude,
  }) {
    return _repository.updateProfile(
      nickname: nickname,
      avatarUrl: avatarUrl,
      certLabels: certLabels,
      serviceRangeKm: serviceRangeKm,
      residentAddress: residentAddress,
      residentLatitude: residentLatitude,
      residentLongitude: residentLongitude,
    );
  }
}
