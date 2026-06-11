import 'api_exception.dart';

sealed class ApiResult<T> {
  const ApiResult();

  bool get isSuccess => this is ApiSuccess<T>;

  bool get isFailure => this is ApiFailure<T>;

  R when<R>({
    required R Function(T data) success,
    required R Function(ApiException error) failure,
  }) {
    if (this case ApiSuccess<T>(data: final data)) {
      return success(data);
    }
    if (this case ApiFailure<T>(error: final error)) {
      return failure(error);
    }
    throw StateError('Unhandled ApiResult subtype');
  }
}

final class ApiSuccess<T> extends ApiResult<T> {
  final T data;

  const ApiSuccess(this.data);
}

final class ApiFailure<T> extends ApiResult<T> {
  final ApiException error;

  const ApiFailure(this.error);
}
