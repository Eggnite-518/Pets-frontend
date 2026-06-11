import 'package:pets/core/network/api_client.dart';
import 'package:pets/core/network/api_response.dart';

import '../models/caretaker_deposit_model.dart';

class CaretakerDepositRemoteDataSource {
  final ApiClient _apiClient;

  const CaretakerDepositRemoteDataSource(this._apiClient);

  Future<ApiResponse<CaretakerDepositModel>> getDeposit() {
    return _apiClient.get<CaretakerDepositModel>(
      path: '/api/v1/caretaker/me/deposit',
      dataParser: (data) {
        final json = Map<String, dynamic>.from(data as Map);
        return CaretakerDepositModel.fromJson(json);
      },
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> rechargeDeposit({
    int targetLevel = 1,
  }) {
    return _apiClient.post<Map<String, dynamic>>(
      path: '/api/v1/caretaker/me/deposit/recharge',
      body: {'targetLevel': targetLevel},
      dataParser: (data) => Map<String, dynamic>.from(data as Map),
    );
  }

  /// 支付宝沙箱充值钱包（page pay HTML）
  Future<ApiResponse<Map<String, dynamic>>> createWalletRecharge({
    required double amount,
    String subject = '钱包充值',
  }) {
    return _apiClient.post<Map<String, dynamic>>(
      path: '/api/v1/users/wallet/recharge',
      body: {
        'amount': amount.toStringAsFixed(2),
        'subject': subject,
      },
      dataParser: (data) => Map<String, dynamic>.from(data as Map),
    );
  }

  /// 支付完成后主动查单入账（notify 延迟或丢失时兜底）
  Future<ApiResponse<Map<String, dynamic>>> confirmWalletRecharge({
    required String outTradeNo,
  }) {
    return _apiClient.post<Map<String, dynamic>>(
      path: '/api/v1/users/wallet/recharge/confirm',
      body: {'outTradeNo': outTradeNo},
      dataParser: (data) => Map<String, dynamic>.from(data as Map),
    );
  }
}
