import '../../domain/entities/caretaker_stats.dart';

class CaretakerStatsModel extends CaretakerStats {
  const CaretakerStatsModel({
    required super.todayOrderCount,
    required super.creditScore,
    required super.pendingPaymentCount,
  });

  factory CaretakerStatsModel.fromJson(Map<String, dynamic> json) {
    return CaretakerStatsModel(
      todayOrderCount: _asInt(json['todayOrderCount']),
      creditScore: _asInt(json['creditScore']),
      pendingPaymentCount: _asInt(json['pendingPaymentCount']),
    );
  }

  CaretakerStats toEntity() => CaretakerStats(
        todayOrderCount: todayOrderCount,
        creditScore: creditScore,
        pendingPaymentCount: pendingPaymentCount,
      );

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
