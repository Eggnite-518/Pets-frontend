/// 跨页面共享：已报名订单 ID（报名成功或后端返回 hasApplied 时写入）
class CaretakerAppliedOrders {
  CaretakerAppliedOrders._();

  static final CaretakerAppliedOrders instance = CaretakerAppliedOrders._();

  final Set<String> orderIds = {};

  bool contains(String orderId) => orderIds.contains(orderId);

  void add(String orderId) => orderIds.add(orderId);
}
