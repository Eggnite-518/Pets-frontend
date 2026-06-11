import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:pets/core/auth/token_storage.dart';
import 'package:pets/core/config/app_config.dart';
import 'package:pets/core/network/api_client.dart';
import 'package:pets/core/network/api_exception.dart';
import 'package:pets/core/network/api_response.dart';

import '../models/fulfillment_record_model.dart';

class FulfillmentRemoteDataSource {
  final ApiClient _apiClient;
  final http.Client _httpClient;

  static const Duration _mediaUploadTimeout = Duration(minutes: 3);

  const FulfillmentRemoteDataSource(this._apiClient, this._httpClient);

  /// API-9 添加履约打卡记录
  /// - 无文件节点：query 参数 `?nodeType=N`
  /// - nodeType=2（入户确认）、nodeType=6（锁门离场/视频）：multipart/form-data，字段 nodeType + file
  /// - lat/lng 可选，传入后后端做距离校验
  Future<ApiResponse<FulfillmentRecordModel>> addFulfillmentRecord({
    required String orderId,
    required int nodeType,
    File? file,
    double? lat,
    double? lng,
  }) async {
    if (file != null) {
      return _addRecordMultipart(
        orderId: orderId,
        nodeType: nodeType,
        file: file,
        lat: lat,
        lng: lng,
      );
    }
    return _apiClient.post<FulfillmentRecordModel>(
      path: _buildFulfillmentPath(
        orderId: orderId,
        nodeType: nodeType,
        lat: lat,
        lng: lng,
      ),
      dataParser: (data) => FulfillmentRecordModel.fromJson(
        Map<String, dynamic>.from(data as Map),
      ),
    );
  }

  String _buildFulfillmentPath({
    required String orderId,
    required int nodeType,
    double? lat,
    double? lng,
  }) {
    final uri = Uri(
      path: '/api/v1/caretaker/orders/$orderId/fulfillment',
      queryParameters: {
        'nodeType': '$nodeType',
        if (lat != null) 'lat': '$lat',
        if (lng != null) 'lng': '$lng',
      },
    );
    final query = uri.hasQuery ? '?${uri.query}' : '';
    return '${uri.path}$query';
  }

  Future<ApiResponse<FulfillmentRecordModel>> _addRecordMultipart({
    required String orderId,
    required int nodeType,
    required File file,
    double? lat,
    double? lng,
  }) async {
    final uri = AppConfig.uri('/api/v1/caretaker/orders/$orderId/fulfillment');
    final token = await TokenStorage.getToken();

    final request = http.MultipartRequest('POST', uri);
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.fields['nodeType'] = nodeType.toString();
    if (lat != null) request.fields['lat'] = lat.toString();
    if (lng != null) request.fields['lng'] = lng.toString();
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: _buildUploadFilename(file.path, nodeType: nodeType),
        contentType: MediaType.parse(_guessMimeType(file.path, nodeType: nodeType)),
      ),
    );

    try {
      final streamed = await _httpClient
          .send(request)
          .timeout(_mediaUploadTimeout);
      final response = await http.Response.fromStream(streamed);
      final bodyText = utf8.decode(response.bodyBytes);
      final dynamic body = bodyText.trim().isEmpty
          ? null
          : jsonDecode(bodyText);

      if (body is Map) {
        final success = body['success'];
        final code = body['code']?.toString();
        final message = body['message']?.toString() ?? '打卡提交失败';
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw ApiException.server(
            message,
            statusCode: response.statusCode,
            businessCode: code,
          );
        }
        if (success == false ||
            (success == null && code != null && code != '0')) {
          throw ApiException(message, businessCode: code);
        }
        final rawData = body['data'];
        if (rawData is Map) {
          return ApiResponse<FulfillmentRecordModel>(
            code: code,
            message: body['message']?.toString() ?? 'ok',
            success: success as bool?,
            data: FulfillmentRecordModel.fromJson(
              Map<String, dynamic>.from(rawData),
            ),
          );
        }
        return ApiResponse<FulfillmentRecordModel>(
          code: code ?? '0',
          message: body['message']?.toString() ?? 'ok',
          success: success as bool? ?? true,
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException.server('打卡提交失败', statusCode: response.statusCode);
      }

      return ApiResponse<FulfillmentRecordModel>(
        code: '0',
        message: 'ok',
        success: true,
      );
    } on ApiException {
      rethrow;
    } on FormatException catch (e) {
      throw ApiException.parse(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException.network(e);
    }
  }

  String _buildUploadFilename(String path, {required int nodeType}) {
    final base = path.split('/').last;
    if (base.contains('.')) {
      return base;
    }
    return nodeType == 6 ? 'fulfillment-video.mp4' : 'fulfillment-photo.jpg';
  }

  String _guessMimeType(String path, {required int nodeType}) {
    final ext = path.split('.').last.toLowerCase();
    if (nodeType == 6) {
      return switch (ext) {
        'mov' => 'video/quicktime',
        'avi' => 'video/x-msvideo',
        'mkv' => 'video/x-matroska',
        'webm' => 'video/webm',
        _ => 'video/mp4',
      };
    }
    return switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      _ => 'image/jpeg',
    };
  }

  Future<ApiResponse<void>> completeOrder(String orderId) {
    return _apiClient.post<void>(
      path: '/api/v1/caretaker/orders/$orderId/complete',
      body: <String, dynamic>{},
    );
  }

  Future<ApiResponse<List<FulfillmentRecordModel>>> getFulfillmentRecords(
    String orderId,
  ) {
    return _apiClient.get<List<FulfillmentRecordModel>>(
      path: '/api/v1/caretaker/orders/$orderId/fulfillment-records',
      dataParser: (data) {
        final map = Map<String, dynamic>.from(data as Map);
        final rawList = map['records'];
        if (rawList is! List) return [];
        return rawList
            .map(
              (e) => FulfillmentRecordModel.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
      },
    );
  }

  Future<ApiResponse<void>> selfReportException({
    required String orderId,
    required int exceptionType,
    required String description,
  }) {
    return _apiClient.post<void>(
      path: '/api/v1/caretaker/orders/$orderId/exception/self-report',
      body: <String, dynamic>{
        'exceptionType': exceptionType,
        'description': description.trim(),
      },
    );
  }

  Future<ApiResponse<void>> noFaultRetreat(String orderId) {
    return _apiClient.post<void>(
      path: '/api/v1/caretaker/orders/$orderId/exception/no-fault-retreat',
      body: <String, dynamic>{},
    );
  }
}
