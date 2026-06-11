class CaretakerStats {
  final int todayOrderCount;
  final int creditScore;
  /// 待支付订单数（宠主已选中但尚未付款），为 0 时首页不展示提示条
  final int pendingPaymentCount;

  const CaretakerStats({
    required this.todayOrderCount,
    required this.creditScore,
    required this.pendingPaymentCount,
  });
}
