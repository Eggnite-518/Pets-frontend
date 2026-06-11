import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pets/core/auth/token_storage.dart';
import 'package:pets/core/config/app_config.dart';
import 'package:pets/core/network/api_exception.dart';
import 'package:pets/core/network/api_result.dart';

class CaretakerVerificationRemoteDataSource {
  final http.Client _client;

  const CaretakerVerificationRemoteDataSource(this._client);

  /// 提交实名认证
  ///
  /// 接口：POST /api/v1/me/real-name-verify（multipart/form-data）
  ///   realName   – 真实姓名（必填）
  ///   idCardNo   – 身份证号码（必填）
  ///   frontImage – 身份证人像面原图（选填，二进制文件）
  ///   backImage  – 身份证国徽面原图（选填，二进制文件）
  Future<ApiResult<void>> submitRealNameVerify({
    required String realName,
    required String idCardNo,
    File? frontImage,
    File? backImage,
  }) async {
    final uri = AppConfig.uri('/api/v1/me/real-name-verify');
    final request = http.MultipartRequest('POST', uri);

    request.fields['realName'] = realName;
    request.fields['idCardNo'] = idCardNo;

    if (frontImage != null) {
      request.files.add(
        await http.MultipartFile.fromPath('frontImage', frontImage.path),
      );
    }
    if (backImage != null) {
      request.files.add(
        await http.MultipartFile.fromPath('backImage', backImage.path),
      );
    }

    final token = await TokenStorage.getToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    try {
      final streamed =
          await _client.send(request).timeout(AppConfig.requestTimeout);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        // 尝试解析后端业务错误信息
        try {
          final body = jsonDecode(utf8.decode(response.bodyBytes));
          if (body is Map) {
            final msg = body['message']?.toString();
            if (msg != null && msg.isNotEmpty) {
              return ApiFailure(ApiException(msg, statusCode: response.statusCode));
            }
          }
        } catch (_) {}
        return ApiFailure(
          ApiException.server('提交失败，请稍后重试', statusCode: response.statusCode),
        );
      }

      // 2xx：解析 success 标志
      try {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body is Map) {
          final success = body['success'];
          if (success == false) {
            final msg = body['message']?.toString() ?? '提交失败，请稍后重试';
            return ApiFailure(ApiException(msg));
          }
        }
      } catch (_) {}

      return const ApiSuccess(null);
    } on ApiException catch (e) {
      return ApiFailure(e);
    } on FormatException catch (e) {
      return ApiFailure(ApiException.parse(e));
    } catch (e) {
      if (e is ApiException) return ApiFailure(e);
      return ApiFailure(ApiException.network(e));
    }
  }
}
