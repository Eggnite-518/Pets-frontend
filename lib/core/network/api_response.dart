typedef JsonDataParser<T> = T Function(Object? json);

class ApiResponse<T> {
  final dynamic code;
  final String message;
  final T? data;
  final String? requestId;

  /// 后端统一响应体中的 success 字段；null 表示旧接口未返回
  final bool? success;

  const ApiResponse({
    required this.code,
    required this.message,
    this.data,
    this.requestId,
    this.success,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json, {
    JsonDataParser<T>? dataParser,
  }) {
    final rawData = json['data'];
    return ApiResponse<T>(
      code: json['code'],
      message: json['message']?.toString() ?? '',
      data: rawData == null
          ? null
          : (dataParser != null ? dataParser(rawData) : rawData as T),
      requestId: json['requestId']?.toString(),
      success: json['success'] as bool?,
    );
  }

  bool get isSuccess {
    // 优先使用后端明确返回的 success 字段
    if (success != null) return success!;
    // fallback：按 code 判断
    final rawCode = code;
    if (rawCode == null) return true;
    if (rawCode is num) return rawCode == 0;
    final normalized = rawCode.toString().trim().toLowerCase();
    return normalized == '0' || normalized == 'success' || normalized == 'ok';
  }
}
