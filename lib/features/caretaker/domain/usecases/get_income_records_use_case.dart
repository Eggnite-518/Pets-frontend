import 'package:pets/core/network/api_result.dart';

import '../entities/caretaker_income_record.dart';
import '../repositories/caretaker_profile_repository.dart';

class GetIncomeRecordsUseCase {
  final CaretakerProfileRepository _repository;

  const GetIncomeRecordsUseCase(this._repository);

  Future<ApiResult<CaretakerIncomeRecordPage>> call({
    int page = 1,
    int pageSize = 20,
  }) {
    return _repository.getIncomeRecords(page: page, pageSize: pageSize);
  }
}
