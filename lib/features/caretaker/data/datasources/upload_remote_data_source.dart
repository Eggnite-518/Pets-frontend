import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pets/core/auth/token_storage.dart';
import 'package:pets/core/config/app_config.dart';
import 'package:pets/core/network/api_exception.dart';

class UploadRemoteDataSource {
  final http.Client _client;

  const UploadRemoteDataSource(this._client);

  /// 上传图片，返回图片访问 URL（对应 API-10）
  Future<String> uploadImage(File imageFile) async {
    final uri = AppConfig.uri('/api/v1/upload/image');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    final token = await TokenStorage.getToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    try {
      final streamed = await _client
          .send(request)
          .timeout(AppConfig.requestTimeout);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException.server('图片上传失败', statusCode: response.statusCode);
      }

      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map) throw ApiException.parse();

      final url = body['data']?['url']?.toString();
      if (url == null || url.isEmpty) {
        throw ApiException.parse();
      }
      return url;
    } on ApiException {
      rethrow;
    } on FormatException catch (e) {
      throw ApiException.parse(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException.network(e);
    }
  }
}
