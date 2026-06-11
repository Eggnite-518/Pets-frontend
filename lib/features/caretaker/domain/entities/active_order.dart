class ActiveOrder {
  final String orderId;
  /// 订单状态：3=待履约，4=履约中，5=待宠主确认
  final int orderStatus;
  final String orderStatusText;
  final String serviceTypeText;
  final String serviceDate;
  final String serviceTimeSlot;
  final String addressSnapshot;
  final String petName;
  final String petAvatarUrl;

  const ActiveOrder({
    required this.orderId,
    required this.orderStatus,
    required this.orderStatusText,
    required this.serviceTypeText,
    required this.serviceDate,
    required this.serviceTimeSlot,
    required this.addressSnapshot,
    required this.petName,
    required this.petAvatarUrl,
  });
}
