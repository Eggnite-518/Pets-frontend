import 'package:pets/core/network/api_result.dart';

import '../entities/caretaker_deposit.dart';
import '../repositories/caretaker_deposit_repository.dart';

class GetCaretakerDepositUseCase {
  final CaretakerDepositRepository _repository;

  const GetCaretakerDepositUseCase(this._repository);

  Future<ApiResult<CaretakerDeposit>> call() => _repository.getDeposit();
}
