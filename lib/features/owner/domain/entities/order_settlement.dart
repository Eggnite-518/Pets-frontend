class OrderSettlement {
  final String settlementId;
  final String orderId;
  final String ownerId;
  final String providerId;
  final String grossAmount;
  final String commissionRate;
  final String commissionAmount;
  final String providerIncome;
  final int settlementStatus;
  final String settlementStatusDesc;
  final String settledAt;

  const OrderSettlement({
    required this.settlementId,
    required this.orderId,
    required this.ownerId,
    required this.providerId,
    required this.grossAmount,
    required this.commissionRate,
    required this.commissionAmount,
    required this.providerIncome,
    required this.settlementStatus,
    required this.settlementStatusDesc,
    required this.settledAt,
  });
}
