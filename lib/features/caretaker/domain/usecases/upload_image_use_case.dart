import 'dart:io';

import 'package:pets/core/network/api_exception.dart';
import 'package:pets/core/network/api_result.dart';

import '../../data/datasources/upload_remote_data_source.dart';

class UploadImageUseCase {
  final UploadRemoteDataSource _dataSource;

  const UploadImageUseCase(this._dataSource);

  Future<ApiResult<String>> call(File imageFile) async {
    try {
      final url = await _dataSource.uploadImage(imageFile);
      return ApiSuccess(url);
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('图片上传失败', cause: e));
    }
  }
}
