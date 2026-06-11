import '../../domain/entities/wallet_withdraw.dart';

class WalletWithdrawModel extends WalletWithdraw {
  const WalletWithdrawModel({
    required super.outBizNo,
    required super.status,
    required super.alipayOrderId,
  });

  factory WalletWithdrawModel.fromJson(Map<String, dynamic> json) {
    return WalletWithdrawModel(
      outBizNo: json['outBizNo']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      alipayOrderId: json['alipayOrderId']?.toString() ?? '',
    );
  }

  WalletWithdraw toEntity() => WalletWithdraw(
    outBizNo: outBizNo,
    status: status,
    alipayOrderId: alipayOrderId,
  );
}
