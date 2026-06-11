import 'package:pets/core/network/api_client.dart';
import 'package:pets/core/network/api_response.dart';

import '../models/caretaker_income_record_model.dart';
import '../models/caretaker_profile_model.dart';
import '../models/caretaker_wallet_model.dart';
import '../models/wallet_recharge_model.dart';
import '../models/wallet_withdraw_model.dart';

class CaretakerProfileRemoteDataSource {
  final ApiClient _apiClient;

  const CaretakerProfileRemoteDataSource(this._apiClient);

  /// API-16 获取宠托师档案
  Future<ApiResponse<CaretakerProfileModel>> getProfile() {
    return _apiClient.get<CaretakerProfileModel>(
      path: '/api/v1/me/caretaker',
      dataParser: (data) {
        final json = Map<String, dynamic>.from(data as Map);
        return CaretakerProfileModel.fromJson(json);
      },
    );
  }

  /// API-17 更新档案
  /// nickname / avatarUrl / certLabels / serviceRangeKm 为后端必填字段。
  /// residentAddress / residentLatitude / residentLongitude 可选（经纬度须同时传或同时不传）。
  Future<ApiResponse<void>> updateProfile({
    required String nickname,
    required String avatarUrl,
    required List<String> certLabels,
    required int serviceRangeKm,
    String? residentAddress,
    double? residentLatitude,
    double? residentLongitude,
  }) {
    final body = <String, dynamic>{
      'nickname': nickname,
      'avatarUrl': avatarUrl,
      'certLabels': certLabels,
      'serviceRangeKm': serviceRangeKm,
    };
    if (residentAddress != null) body['residentAddress'] = residentAddress;
    if (residentLatitude != null) body['residentLatitude'] = residentLatitude;
    if (residentLongitude != null) {
      body['residentLongitude'] = residentLongitude;
    }
    return _apiClient.put<void>(path: '/api/v1/me/caretaker', body: body);
  }

  /// API-18 获取钱包余额
  Future<ApiResponse<CaretakerWalletModel>> getWallet() {
    return _apiClient.get<CaretakerWalletModel>(
      path: '/api/v1/caretaker/me/wallet',
      dataParser: (data) {
        final json = Map<String, dynamic>.from(data as Map);
        return CaretakerWalletModel.fromJson(json);
      },
    );
  }

  /// 获取当前用户钱包余额（宠主/宠托通用）
  Future<ApiResponse<CaretakerWalletModel>> getCurrentUserWallet() {
    return _apiClient.get<CaretakerWalletModel>(
      path: '/api/v1/users/wallet',
      dataParser: (data) {
        final json = Map<String, dynamic>.from(data as Map);
        return CaretakerWalletModel.fromJson(json);
      },
    );
  }

  /// 发起钱包充值，后端返回支付宝网页支付 form
  Future<ApiResponse<WalletRechargeModel>> rechargeWallet({
    required num amount,
    String subject = '账户充值',
  }) {
    return _apiClient.post<WalletRechargeModel>(
      path: '/api/v1/users/wallet/recharge',
      body: {'amount': amount, 'subject': subject},
      dataParser: (data) {
        final json = Map<String, dynamic>.from(data as Map);
        return WalletRechargeModel.fromJson(json);
      },
    );
  }

  /// 通用钱包提现，宠主/宠托都可使用
  Future<ApiResponse<WalletWithdrawModel>> withdrawWallet({
    required num amount,
    required String payeeAccount,
    String? payeeRealName,
    String? remark,
  }) {
    final body = <String, dynamic>{
      'amount': amount,
      'payeeAccount': payeeAccount,
    };
    if (payeeRealName != null && payeeRealName.isNotEmpty) {
      body['payeeRealName'] = payeeRealName;
    }
    if (remark != null && remark.isNotEmpty) {
      body['remark'] = remark;
    }
    return _apiClient.post<WalletWithdrawModel>(
      path: '/api/v1/users/wallet/withdraw',
      body: body,
      dataParser: (data) {
        final json = Map<String, dynamic>.from(data as Map);
        return WalletWithdrawModel.fromJson(json);
      },
    );
  }

  /// API-19 申请提现（金额为整数，最低 10 元）
  /// 返回提现后的最新余额
  Future<ApiResponse<CaretakerWalletModel>> withdraw({required int amount}) {
    return _apiClient.post<CaretakerWalletModel>(
      path: '/api/v1/caretaker/me/wallet/withdraw',
      body: {'amount': amount},
      dataParser: (data) {
        final json = Map<String, dynamic>.from(data as Map);
        return CaretakerWalletModel.fromJson(json);
      },
    );
  }

  /// API-20 获取钱包流水记录（分页）
  Future<ApiResponse<CaretakerIncomeRecordPageModel>> getIncomeRecords({
    int page = 1,
    int pageSize = 20,
  }) {
    return _apiClient.get<CaretakerIncomeRecordPageModel>(
      path: '/api/v1/caretaker/me/wallet/records?page=$page&pageSize=$pageSize',
      dataParser: (data) {
        final json = Map<String, dynamic>.from(data as Map);
        return CaretakerIncomeRecordPageModel.fromJson(json);
      },
    );
  }
}
