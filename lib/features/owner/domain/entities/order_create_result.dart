class OrderCreateResult {
  final String orderId;
  final int orderStatus;
  final String orderStatusText;
  final String totalAmount;
  final int serviceType;
  final String serviceTypeText;
  final String serviceDate;
  final String serviceStartTime;
  final String serviceEndTime;
  final String createdAt;

  const OrderCreateResult({
    required this.orderId,
    required this.orderStatus,
    required this.orderStatusText,
    required this.totalAmount,
    required this.serviceType,
    required this.serviceTypeText,
    required this.serviceDate,
    required this.serviceStartTime,
    required this.serviceEndTime,
    required this.createdAt,
  });
}
