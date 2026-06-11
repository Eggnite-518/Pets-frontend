import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pets/core/auth/token_storage.dart';
import 'package:pets/core/config/app_config.dart';
import 'package:pets/core/network/api_exception.dart';
import 'package:pets/core/network/api_result.dart';

class IdCardOcrResult {
  final String? realName;
  final String? idCardNo;
  final String? birthDate;
  final String? gender;
  final String? nationality;
  final String? address;

  const IdCardOcrResult({
    this.realName,
    this.idCardNo,
    this.birthDate,
    this.gender,
    this.nationality,
    this.address,
  });

  factory IdCardOcrResult.fromJson(Map<String, dynamic> json) {
    return IdCardOcrResult(
      realName: json['realName']?.toString(),
      idCardNo: json['idCardNo']?.toString(),
      birthDate: json['birthDate']?.toString(),
      gender: json['gender']?.toString(),
      nationality: json['nationality']?.toString(),
      address: json['address']?.toString(),
    );
  }
}

class OcrRemoteDataSource {
  final http.Client _client;

  const OcrRemoteDataSource(this._client);

  /// 身份证 OCR 识别
  ///
  /// [side] "face"（人像面，默认）或 "back"（国徽面）
  /// 返回 [IdCardOcrResult]，其中 realName/idCardNo 由正面识别得出
  Future<ApiResult<IdCardOcrResult>> recognizeIdCard(
    File imageFile, {
    String side = 'face',
  }) async {
    final uri = AppConfig.uri('/api/v1/ocr/id-card');
    final request = http.MultipartRequest('POST', uri);
    request.fields['side'] = side;
    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    final token = await TokenStorage.getToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    try {
      final streamed =
          await _client.send(request).timeout(AppConfig.requestTimeout);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return ApiFailure(
          ApiException.server('身份证识别失败', statusCode: response.statusCode),
        );
      }

      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map) return ApiFailure(ApiException.parse());

      final data = body['data'];
      if (data == null) {
        return ApiFailure(ApiException('识别结果为空，请确保照片清晰'));
      }

      return ApiSuccess(
        IdCardOcrResult.fromJson(Map<String, dynamic>.from(data as Map)),
      );
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
