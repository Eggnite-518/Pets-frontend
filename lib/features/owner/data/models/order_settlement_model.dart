import '../../domain/entities/order_settlement.dart';

class OrderSettlementModel extends OrderSettlement {
  const OrderSettlementModel({
    required super.settlementId,
    required super.orderId,
    required super.ownerId,
    required super.providerId,
    required super.grossAmount,
    required super.commissionRate,
    required super.commissionAmount,
    required super.providerIncome,
    required super.settlementStatus,
    required super.settlementStatusDesc,
    required super.settledAt,
  });

  factory OrderSettlementModel.fromJson(Map<String, dynamic> json) {
    return OrderSettlementModel(
      settlementId: json['settlementId']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      ownerId: json['ownerId']?.toString() ?? '',
      providerId: json['providerId']?.toString() ?? '',
      grossAmount: json['grossAmount']?.toString() ?? '0.00',
      commissionRate: json['commissionRate']?.toString() ?? '0.00',
      commissionAmount: json['commissionAmount']?.toString() ?? '0.00',
      providerIncome: json['providerIncome']?.toString() ?? '0.00',
      settlementStatus: _toInt(json['settlementStatus']),
      settlementStatusDesc: json['settlementStatusDesc']?.toString() ?? '',
      settledAt: json['settledAt']?.toString() ?? '',
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
