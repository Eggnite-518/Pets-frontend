import 'dart:math';

class CaretakerDeposit {
  final double depositAmount;
  final double basicRequiredAmount;
  final bool basicReady;
  final double walletBalance;
  final double frozenAmount;
  final String custodyRule;

  const CaretakerDeposit({
    required this.depositAmount,
    required this.basicRequiredAmount,
    required this.basicReady,
    required this.walletBalance,
    required this.frozenAmount,
    required this.custodyRule,
  });

  /// 距基础保证金（200）还需缴纳的金额
  double get amountStillNeeded =>
      max(0, basicRequiredAmount - depositAmount).toDouble();

  /// 钱包余额缺口（需先支付宝充值的部分）
  double get walletShortfall =>
      max(0, amountStillNeeded - walletBalance).toDouble();

  bool get canPayDepositFromWallet =>
      basicReady || walletBalance >= amountStillNeeded;
}

class WalletRechargeOrder {
  final String outTradeNo;
  final String payFormHtml;

  const WalletRechargeOrder({
    required this.outTradeNo,
    required this.payFormHtml,
  });
}
