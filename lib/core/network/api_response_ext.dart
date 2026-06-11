import 'api_exception.dart';
import 'api_response.dart';

extension ApiResponseFailureX<T> on ApiResponse<T> {
  ApiException toException([String fallback = '请求失败']) {
    return ApiException(
      message.isNotEmpty ? message : fallback,
      businessCode: code?.toString(),
    );
  }
}
