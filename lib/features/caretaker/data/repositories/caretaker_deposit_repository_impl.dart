import 'package:pets/core/network/api_exception.dart';
import 'package:pets/core/network/api_response_ext.dart';
import 'package:pets/core/network/api_result.dart';

import '../../domain/entities/caretaker_deposit.dart';
import '../../domain/repositories/caretaker_deposit_repository.dart';
import '../datasources/caretaker_deposit_remote_data_source.dart';
import '../models/caretaker_deposit_model.dart';

class CaretakerDepositRepositoryImpl implements CaretakerDepositRepository {
  final CaretakerDepositRemoteDataSource _remoteDataSource;

  const CaretakerDepositRepositoryImpl(this._remoteDataSource);

  @override
  Future<ApiResult<CaretakerDeposit>> getDeposit() async {
    try {
      final response = await _remoteDataSource.getDeposit();
      if (!response.isSuccess) {
        return ApiFailure(response.toException('获取保证金信息失败'));
      }
      final data = response.data;
      if (data == null) {
        return const ApiFailure(ApiException('保证金信息为空'));
      }
      return ApiSuccess(data.toEntity());
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('获取保证金信息失败', cause: e));
    }
  }

  @override
  Future<ApiResult<CaretakerDeposit>> rechargeDeposit({
    int targetLevel = 1,
  }) async {
    try {
      final response = await _remoteDataSource.rechargeDeposit(
        targetLevel: targetLevel,
      );
      if (!response.isSuccess) {
        return ApiFailure(response.toException('缴纳保证金失败'));
      }
      return getDeposit();
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('缴纳保证金失败', cause: e));
    }
  }

  @override
  Future<ApiResult<WalletRechargeOrder>> createWalletRecharge({
    required double amount,
    String subject = '钱包充值',
  }) async {
    try {
      final response = await _remoteDataSource.createWalletRecharge(
        amount: amount,
        subject: subject,
      );
      if (!response.isSuccess) {
        return ApiFailure(response.toException('创建充值订单失败'));
      }
      final data = response.data;
      if (data == null) {
        return const ApiFailure(ApiException('充值订单为空'));
      }
      final html = data['payForm']?.toString() ?? '';
      if (html.isEmpty) {
        return const ApiFailure(ApiException('支付宝支付表单为空'));
      }
      return ApiSuccess(WalletRechargeOrder(
        outTradeNo: data['outTradeNo']?.toString() ?? '',
        payFormHtml: html,
      ));
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('创建充值订单失败', cause: e));
    }
  }

  @override
  Future<ApiResult<bool>> confirmWalletRecharge({
    required String outTradeNo,
  }) async {
    try {
      final response = await _remoteDataSource.confirmWalletRecharge(
        outTradeNo: outTradeNo,
      );
      if (!response.isSuccess) {
        return ApiFailure(response.toException('确认充值失败'));
      }
      final data = response.data;
      final paid = data?['paid'] == true;
      return ApiSuccess(paid);
    } on ApiException catch (e) {
      return ApiFailure(e);
    } catch (e) {
      return ApiFailure(ApiException('确认充值失败', cause: e));
    }
  }
}
