import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../auth/token_storage.dart';
import '../config/app_config.dart';
import 'api_exception.dart';
import 'api_response.dart';

class ApiClient {
  static void Function()? onAuthError;

  final http.Client _client;
  final Duration _requestTimeout;

  ApiClient({http.Client? client, Duration? requestTimeout})
    : _client = client ?? http.Client(),
      _requestTimeout = requestTimeout ?? AppConfig.requestTimeout;

  Future<ApiResponse<T>> get<T>({
    required String path,
    Map<String, String>? headers,
    JsonDataParser<T>? dataParser,
  }) {
    return _send<T>(
      method: 'GET',
      path: path,
      headers: headers,
      dataParser: dataParser,
    );
  }

  Future<ApiResponse<T>> post<T>({
    required String path,
    Object? body,
    Map<String, String>? headers,
    JsonDataParser<T>? dataParser,
  }) {
    return _send<T>(
      method: 'POST',
      path: path,
      body: body,
      headers: headers,
      dataParser: dataParser,
    );
  }

  Future<ApiResponse<T>> put<T>({
    required String path,
    Object? body,
    Map<String, String>? headers,
    JsonDataParser<T>? dataParser,
  }) {
    return _send<T>(
      method: 'PUT',
      path: path,
      body: body,
      headers: headers,
      dataParser: dataParser,
    );
  }

  Future<ApiResponse<T>> delete<T>({
    required String path,
    Object? body,
    Map<String, String>? headers,
    JsonDataParser<T>? dataParser,
  }) {
    return _send<T>(
      method: 'DELETE',
      path: path,
      body: body,
      headers: headers,
      dataParser: dataParser,
    );
  }

  Future<ApiResponse<T>> _send<T>({
    required String method,
    required String path,
    Object? body,
    Map<String, String>? headers,
    JsonDataParser<T>? dataParser,
  }) async {
    final uri = AppConfig.uri(path);
    final requestHeaders = <String, String>{
      'Content-Type': 'application/json',
      ...?headers,
    };

    final token = await TokenStorage.getToken();
    if (token != null &&
        token.isNotEmpty &&
        !requestHeaders.containsKey('Authorization')) {
      requestHeaders['Authorization'] = 'Bearer $token';
    }

    try {
      final response = switch (method) {
        'GET' =>
          await _client
              .get(uri, headers: requestHeaders)
              .timeout(_requestTimeout),
        'POST' =>
          await _client
              .post(
                uri,
                headers: requestHeaders,
                body: body == null
                    ? null
                    : body is String
                    ? body
                    : jsonEncode(body),
              )
              .timeout(_requestTimeout),
        'PUT' =>
          await _client
              .put(
                uri,
                headers: requestHeaders,
                body: body == null
                    ? null
                    : body is String
                    ? body
                    : jsonEncode(body),
              )
              .timeout(_requestTimeout),
        'DELETE' =>
          await _client
              .delete(
                uri,
                headers: requestHeaders,
                body: body == null
                    ? null
                    : body is String
                    ? body
                    : jsonEncode(body),
              )
              .timeout(_requestTimeout),
        _ => throw UnsupportedError('Unsupported method: $method'),
      };

      return _decodeResponse<T>(response, dataParser);
    } on TimeoutException catch (error) {
      throw ApiException.timeout(error);
    } on http.ClientException catch (error) {
      throw ApiException.network(error);
    } on SocketException catch (error) {
      throw ApiException.network(error);
    } on FormatException catch (error) {
      throw ApiException.parse(error);
    }
  }

  ApiResponse<T> _decodeResponse<T>(
    http.Response response,
    JsonDataParser<T>? dataParser,
  ) {
    final bodyText = utf8.decode(response.bodyBytes);

    if (bodyText.trim().isEmpty) {
      if (_isSuccessStatus(response.statusCode)) {
        return ApiResponse<T>(code: response.statusCode, message: 'success');
      }
      throw ApiException.server('请求失败', statusCode: response.statusCode);
    }

    final dynamic decodedBody;
    try {
      decodedBody = jsonDecode(bodyText);
    } on FormatException catch (error) {
      if (_isSuccessStatus(response.statusCode)) {
        throw ApiException.parse(error);
      }
      throw ApiException.server(
        bodyText,
        statusCode: response.statusCode,
        cause: error,
      );
    }

    if (decodedBody is! Map<String, dynamic>) {
      throw ApiException.parse();
    }

    if (!_isSuccessStatus(response.statusCode)) {
      if (response.statusCode == 401) {
        onAuthError?.call();
      }
      throw ApiException.server(
        _extractMessage(decodedBody) ?? '请求失败',
        statusCode: response.statusCode,
        businessCode: decodedBody['code']?.toString(),
      );
    }

    return ApiResponse<T>.fromJson(decodedBody, dataParser: dataParser);
  }

  String? _extractMessage(Map<String, dynamic> body) {
    final message = body['message'];
    return message?.toString();
  }

  bool _isSuccessStatus(int statusCode) {
    return statusCode >= 200 && statusCode < 300;
  }

  void close() {
    _client.close();
  }
}
