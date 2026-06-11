import 'package:pets/core/network/api_result.dart';

import '../entities/caretaker_deposit.dart';
import '../repositories/caretaker_deposit_repository.dart';

class WalletRechargeUseCase {
  final CaretakerDepositRepository _repository;

  const WalletRechargeUseCase(this._repository);

  Future<ApiResult<WalletRechargeOrder>> call({
    required double amount,
    String subject = '钱包充值',
  }) {
    return _repository.createWalletRecharge(amount: amount, subject: subject);
  }
}
