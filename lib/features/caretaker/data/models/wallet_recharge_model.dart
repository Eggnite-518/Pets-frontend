import '../../domain/entities/wallet_recharge.dart';

class WalletRechargeModel extends WalletRecharge {
  const WalletRechargeModel({
    required super.outTradeNo,
    required super.payForm,
  });

  factory WalletRechargeModel.fromJson(Map<String, dynamic> json) {
    return WalletRechargeModel(
      outTradeNo: json['outTradeNo']?.toString() ?? '',
      payForm: json['payForm']?.toString() ?? '',
    );
  }

  WalletRecharge toEntity() =>
      WalletRecharge(outTradeNo: outTradeNo, payForm: payForm);
}
