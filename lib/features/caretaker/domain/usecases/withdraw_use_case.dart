import 'package:pets/core/network/api_result.dart';

import '../entities/caretaker_wallet.dart';
import '../repositories/caretaker_profile_repository.dart';

class WithdrawUseCase {
  final CaretakerProfileRepository _repository;

  const WithdrawUseCase(this._repository);

  Future<ApiResult<CaretakerWallet>> call({required int amount}) {
    return _repository.withdraw(amount: amount);
  }
}
