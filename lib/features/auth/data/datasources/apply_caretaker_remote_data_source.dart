import 'package:pets/core/network/api_client.dart';
import 'package:pets/core/network/api_exception.dart';
import 'package:pets/core/network/api_result.dart';

class ApplyCaretakerResult {
  /// 服务端返回的新 token（若后端在 apply 接口直接颁发新 token 则不为 null）
  final String? newToken;
  const ApplyCaretakerResult({this.newToken});
}

class ApplyCaretakerRemoteDataSource {
  final ApiClient _apiClient;

  const ApplyCaretakerRemoteDataSource(this._apiClient);

  /// 申请成为宠托师
  ///
  /// 后端约定接口：POST /api/v1/me/apply-caretaker
  /// 调用后后端将用户 roleType 升级为 2（宠托师）。
  /// 若后端在响应 data 中返回新 token，前端直接替换；否则需要用户重新登录。
  Future<ApiResult<ApplyCaretakerResult>> applyCaretaker() async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        path: '/api/v1/me/apply-caretaker',
        body: {},
        dataParser: (data) {
          if (data is Map) return Map<String, dynamic>.from(data);
          return {};
        },
      );

      if (!response.isSuccess) {
        final msg = response.message.trim();
        return ApiFailure(ApiException(msg.isEmpty ? '申请失败，请稍后重试' : msg));
      }

      final newToken = response.data?['token']?.toString();
      return ApiSuccess(ApplyCaretakerResult(newToken: newToken));
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('申请失败，请稍后重试', cause: e));
    }
  }
}
