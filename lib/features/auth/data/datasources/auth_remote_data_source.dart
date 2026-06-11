import 'package:pets/core/auth/auth_token_store.dart';
import 'package:pets/core/network/api_client.dart';
import 'package:pets/core/network/api_exception.dart';
import 'package:pets/core/network/api_result.dart';

import '../models/login_user_model.dart';
import '../models/register_user_model.dart';

class AuthRemoteDataSource {
  final ApiClient _apiClient;

  const AuthRemoteDataSource(this._apiClient);

  /// 登录，成功后自动保存 token
  Future<ApiResult<LoginUserModel>> login({
    required String phone,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post<LoginUserModel>(
        path: '/api/v1/auth/login',
        body: {'phone': phone, 'password': password},
        dataParser: (data) =>
            LoginUserModel.fromJson(Map<String, dynamic>.from(data as Map)),
      );

      if (!response.isSuccess) {
        return ApiFailure(
          ApiException(
            response.message,
            businessCode: response.code?.toString(),
          ),
        );
      }

      final user = response.data;
      if (user == null) {
        return const ApiFailure(ApiException('登录响应数据为空'));
      }

      await AuthTokenStore.instance.writeToken(user.token);
      return ApiSuccess(user);
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('登录失败', cause: e));
    }
  }

  Future<ApiResult<void>> sendCode({required String phone}) async {
    try {
      final response = await _apiClient.post<void>(
        path: '/api/v1/auth/send-code',
        body: {'phone': phone},
      );

      if (!response.isSuccess) {
        return ApiFailure(
          ApiException(
            response.message,
            businessCode: response.code?.toString(),
          ),
        );
      }

      return ApiSuccess<void>(null);
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('发送验证码失败', cause: e));
    }
  }

  Future<ApiResult<LoginUserModel>> loginByCode({
    required String phone,
    required String code,
  }) async {
    try {
      final response = await _apiClient.post<LoginUserModel>(
        path: '/api/v1/auth/login-by-code',
        body: {'phone': phone, 'code': code},
        dataParser: (data) =>
            LoginUserModel.fromJson(Map<String, dynamic>.from(data as Map)),
      );

      if (!response.isSuccess) {
        return ApiFailure(
          ApiException(
            response.message,
            businessCode: response.code?.toString(),
          ),
        );
      }

      final user = response.data;
      if (user == null) {
        return const ApiFailure(ApiException('验证码登录响应数据为空'));
      }

      await AuthTokenStore.instance.writeToken(user.token);
      return ApiSuccess(user);
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('验证码登录失败', cause: e));
    }
  }

  Future<ApiResult<RegisterUserModel>> register({
    required String nickname,
    required String phone,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post<RegisterUserModel>(
        path: '/api/v1/auth/register',
        body: {'nickname': nickname, 'phone': phone, 'password': password},
        dataParser: (data) =>
            RegisterUserModel.fromJson(Map<String, dynamic>.from(data as Map)),
      );

      if (!response.isSuccess) {
        return ApiFailure(
          ApiException(
            response.message,
            businessCode: response.code?.toString(),
          ),
        );
      }

      final user = response.data;
      if (user == null) {
        return const ApiFailure(ApiException('注册响应数据为空'));
      }

      return ApiSuccess(user);
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('注册失败', cause: e));
    }
  }

  Future<ApiResult<void>> setPassword({required String newPassword}) async {
    try {
      final response = await _apiClient.post<void>(
        path: '/api/v1/auth/set-password',
        body: {'newPassword': newPassword},
      );

      if (!response.isSuccess) {
        return ApiFailure(
          ApiException(
            response.message,
            businessCode: response.code?.toString(),
          ),
        );
      }

      return ApiSuccess<void>(null);
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('设置密码失败', cause: e));
    }
  }

  Future<ApiResult<void>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _apiClient.post<void>(
        path: '/api/v1/auth/change-password',
        body: {'oldPassword': oldPassword, 'newPassword': newPassword},
      );

      if (!response.isSuccess) {
        return ApiFailure(
          ApiException(
            response.message,
            businessCode: response.code?.toString(),
          ),
        );
      }

      return ApiSuccess<void>(null);
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('修改密码失败', cause: e));
    }
  }

  Future<ApiResult<void>> deactivateAccount() async {
    try {
      final response = await _apiClient.post<void>(
        path: '/api/v1/me/deactivate',
      );

      if (!response.isSuccess) {
        return ApiFailure(
          ApiException(
            response.message,
            businessCode: response.code?.toString(),
          ),
        );
      }

      await AuthTokenStore.instance.clearAll();
      return ApiSuccess<void>(null);
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('账号注销失败', cause: e));
    }
  }

  /// 退出登录，清理本地 token
  Future<void> logout() async {
    await AuthTokenStore.instance.clearAll();
  }
}
