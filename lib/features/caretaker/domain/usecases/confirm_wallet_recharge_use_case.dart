import 'package:pets/core/network/api_result.dart';

import '../repositories/caretaker_deposit_repository.dart';

class ConfirmWalletRechargeUseCase {
  final CaretakerDepositRepository _repository;

  const ConfirmWalletRechargeUseCase(this._repository);

  Future<ApiResult<bool>> call({required String outTradeNo}) {
    return _repository.confirmWalletRecharge(outTradeNo: outTradeNo);
  }
}
