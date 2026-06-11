import 'package:pets/core/network/api_result.dart';

import '../entities/caretaker_deposit.dart';

abstract class CaretakerDepositRepository {
  Future<ApiResult<CaretakerDeposit>> getDeposit();

  Future<ApiResult<CaretakerDeposit>> rechargeDeposit({int targetLevel = 1});

  Future<ApiResult<WalletRechargeOrder>> createWalletRecharge({
    required double amount,
    String subject,
  });

  Future<ApiResult<bool>> confirmWalletRecharge({required String outTradeNo});
}
