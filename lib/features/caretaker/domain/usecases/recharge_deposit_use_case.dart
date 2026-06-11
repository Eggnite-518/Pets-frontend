import 'package:pets/core/network/api_result.dart';

import '../entities/caretaker_deposit.dart';
import '../repositories/caretaker_deposit_repository.dart';

class RechargeDepositUseCase {
  final CaretakerDepositRepository _repository;

  const RechargeDepositUseCase(this._repository);

  Future<ApiResult<CaretakerDeposit>> call({int targetLevel = 1}) {
    return _repository.rechargeDeposit(targetLevel: targetLevel);
  }
}
