import 'package:pets/core/network/api_result.dart';

import '../entities/caretaker_income_record.dart';
import '../entities/caretaker_profile.dart';
import '../entities/caretaker_wallet.dart';

abstract class CaretakerProfileRepository {
  Future<ApiResult<CaretakerProfile>> getProfile();

  /// 后端要求 nickname / avatarUrl / certLabels / serviceRangeKm 四个字段必传；
  /// residentAddress / residentLatitude / residentLongitude 可选（经纬度须同时传或同时不传）。
  Future<ApiResult<void>> updateProfile({
    required String nickname,
    required String avatarUrl,
    required List<String> certLabels,
    required int serviceRangeKm,
    String? residentAddress,
    double? residentLatitude,
    double? residentLongitude,
  });
  Future<ApiResult<CaretakerWallet>> getWallet();

  /// 申请提现；返回提现后的最新钱包状态
  Future<ApiResult<CaretakerWallet>> withdraw({required int amount});

  /// 获取钱包流水记录（分页）
  Future<ApiResult<CaretakerIncomeRecordPage>> getIncomeRecords({
    int page,
    int pageSize,
  });
}
