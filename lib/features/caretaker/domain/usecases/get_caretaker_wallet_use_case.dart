import 'package:pets/core/network/api_result.dart';

import '../entities/caretaker_wallet.dart';
import '../repositories/caretaker_profile_repository.dart';

class GetCaretakerWalletUseCase {
  final CaretakerProfileRepository _repository;

  const GetCaretakerWalletUseCase(this._repository);

  Future<ApiResult<CaretakerWallet>> call() {
    return _repository.getWallet();
  }
}
