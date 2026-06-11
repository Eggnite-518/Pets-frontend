import 'package:pets/core/network/api_exception.dart';
import 'package:pets/core/network/api_result.dart';

import '../../domain/entities/caretaker_income_record.dart';
import '../../domain/entities/caretaker_profile.dart';
import '../../domain/entities/caretaker_wallet.dart';
import '../../domain/repositories/caretaker_profile_repository.dart';
import '../datasources/caretaker_profile_remote_data_source.dart';

/// 新用户注册后尚未填写档案时后端返回 data=null，用此默认值代替错误
const _kEmptyProfile = CaretakerProfile(
  nickname: '',
  avatarUrl: '',
  serviceRangeKm: 5,
  certTags: [],
  certLabels: [],
  rating: 0,
  reviewCount: 0,
  levelTag: '',
);

class CaretakerProfileRepositoryImpl implements CaretakerProfileRepository {
  final CaretakerProfileRemoteDataSource _remoteDataSource;

  const CaretakerProfileRepositoryImpl(this._remoteDataSource);

  @override
  Future<ApiResult<CaretakerProfile>> getProfile() async {
    try {
      final response = await _remoteDataSource.getProfile();
      final data = response.data;
      // data=null 是新用户尚未填写档案的正常状态，返回空档案而不是错误
      if (data == null) return const ApiSuccess(_kEmptyProfile);
      return ApiSuccess(data.toEntity());
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('获取档案失败', cause: e));
    }
  }

  @override
  Future<ApiResult<void>> updateProfile({
    required String nickname,
    required String avatarUrl,
    required List<String> certLabels,
    required int serviceRangeKm,
    String? residentAddress,
    double? residentLatitude,
    double? residentLongitude,
  }) async {
    try {
      final response = await _remoteDataSource.updateProfile(
        nickname: nickname,
        avatarUrl: avatarUrl,
        certLabels: certLabels,
        serviceRangeKm: serviceRangeKm,
        residentAddress: residentAddress,
        residentLatitude: residentLatitude,
        residentLongitude: residentLongitude,
      );
      if (!response.isSuccess) {
        return ApiFailure(ApiException(
          response.message.isNotEmpty ? response.message : '更新档案失败',
        ));
      }
      return const ApiSuccess(null);
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('更新档案失败', cause: e));
    }
  }

  @override
  Future<ApiResult<CaretakerWallet>> getWallet() async {
    try {
      final response = await _remoteDataSource.getWallet();
      final data = response.data;
      if (data == null) {
        return const ApiFailure(ApiException('钱包数据为空'));
      }
      return ApiSuccess(data.toEntity());
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('获取余额失败', cause: e));
    }
  }

  @override
  Future<ApiResult<CaretakerWallet>> withdraw({required int amount}) async {
    try {
      final response = await _remoteDataSource.withdraw(amount: amount);
      final data = response.data;
      if (data == null) {
        return const ApiFailure(ApiException('提现响应为空'));
      }
      return ApiSuccess(data.toEntity());
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('提现失败', cause: e));
    }
  }

  @override
  Future<ApiResult<CaretakerIncomeRecordPage>> getIncomeRecords({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _remoteDataSource.getIncomeRecords(
        page: page,
        pageSize: pageSize,
      );
      final data = response.data;
      if (data == null) {
        return const ApiFailure(ApiException('流水数据为空'));
      }
      return ApiSuccess(data.toEntity());
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('获取收入明细失败', cause: e));
    }
  }
}
