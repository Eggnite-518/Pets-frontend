class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Object? cause;
  final String? businessCode;

  const ApiException(
    this.message, {
    this.statusCode,
    this.cause,
    this.businessCode,
  });

  factory ApiException.network([Object? cause]) {
    return ApiException('网络连接失败，请检查网络后重试', cause: cause);
  }

  factory ApiException.timeout([Object? cause]) {
    return ApiException('请求超时，请稍后重试', cause: cause);
  }

  factory ApiException.parse([Object? cause]) {
    return ApiException('数据解析失败，请联系客服', cause: cause);
  }

  factory ApiException.server(
    String message, {
    int? statusCode,
    Object? cause,
    String? businessCode,
  }) {
    return ApiException(
      message,
      statusCode: statusCode,
      cause: cause,
      businessCode: businessCode,
    );
  }

  @override
  String toString() {
    return 'ApiException(message: $message, statusCode: $statusCode, businessCode: $businessCode, cause: $cause)';
  }
}
