import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pets/core/auth/token_storage.dart';
import 'package:pets/core/config/app_config.dart';
import 'package:pets/core/network/api_client.dart';
import 'package:pets/core/network/api_exception.dart';
import 'package:pets/core/network/api_response.dart';

import '../models/review_attachment_model.dart';
import '../models/order_rating_detail_model.dart';
import '../models/submit_order_review_request.dart';

class ReviewRemoteDataSource {
  final ApiClient _apiClient;
  final http.Client _httpClient;

  ReviewRemoteDataSource(this._apiClient, {http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  Future<ApiResponse<ReviewAttachmentModel>> uploadAttachment({
    required String filePath,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      AppConfig.uri('/api/v1/reviews/attachments/upload'),
    );

    final token = await TokenStorage.getToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    try {
      final streamedResponse = await _httpClient
          .send(request)
          .timeout(AppConfig.requestTimeout);
      final response = await http.Response.fromStream(streamedResponse);
      return _decodeUploadResponse(response);
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

  Future<ApiResponse<void>> submitReview({
    required String orderId,
    required SubmitOrderReviewRequest request,
  }) {
    return _apiClient.post<void>(
      path: '/api/v1/orders/$orderId/rating',
      body: request.toJson(),
    );
  }

  Future<ApiResponse<OrderRatingDetailModel>> getRating({
    required String orderId,
  }) {
    return _apiClient.get<OrderRatingDetailModel>(
      path: '/api/v1/orders/$orderId/rating',
      dataParser: (data) => OrderRatingDetailModel.fromJson(
        Map<String, dynamic>.from(data as Map),
      ),
    );
  }

  ApiResponse<ReviewAttachmentModel> _decodeUploadResponse(
    http.Response response,
  ) {
    final bodyText = utf8.decode(response.bodyBytes);
    if (bodyText.trim().isEmpty) {
      throw ApiException.server('附件上传响应为空', statusCode: response.statusCode);
    }

    final decodedBody = jsonDecode(bodyText);
    if (decodedBody is! Map<String, dynamic>) {
      throw ApiException.parse();
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.server(
        decodedBody['message']?.toString() ?? '附件上传失败',
        statusCode: response.statusCode,
      );
    }

    return ApiResponse<ReviewAttachmentModel>.fromJson(
      decodedBody,
      dataParser: (data) => ReviewAttachmentModel.fromJson(
        Map<String, dynamic>.from(data as Map),
      ),
    );
  }

  void close() {
    _httpClient.close();
  }
}
