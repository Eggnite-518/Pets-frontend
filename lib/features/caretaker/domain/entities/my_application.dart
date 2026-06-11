class MyApplication {
  final String applicationId;
  final String orderId;
  /// 订单状态，同全站枚举：1=悬赏中（API-4 只返回此值）
  final int orderStatus;
  final String orderStatusText;
  final int serviceType;
  final String serviceTypeText;
  final int totalAmount;
  final double distanceKm;
  final String serviceDate;
  final String serviceTimeSlot;
  final String addressSnapshot;
  final String petName;
  final String petAvatarUrl;

  const MyApplication({
    required this.applicationId,
    required this.orderId,
    required this.orderStatus,
    required this.orderStatusText,
    required this.serviceType,
    required this.serviceTypeText,
    required this.totalAmount,
    required this.distanceKm,
    required this.serviceDate,
    required this.serviceTimeSlot,
    required this.addressSnapshot,
    required this.petName,
    required this.petAvatarUrl,
  });
}
