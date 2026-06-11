import '../../domain/entities/caretaker_deposit.dart';

class CaretakerDepositModel extends CaretakerDeposit {
  const CaretakerDepositModel({
    required super.depositAmount,
    required super.basicRequiredAmount,
    required super.basicReady,
    required super.walletBalance,
    required super.frozenAmount,
    required super.custodyRule,
  });

  factory CaretakerDepositModel.fromJson(Map<String, dynamic> json) {
    return CaretakerDepositModel(
      depositAmount: _asDouble(json['depositAmount']),
      basicRequiredAmount: _asDouble(json['basicRequiredAmount'], fallback: 200),
      basicReady: json['basicReady'] == true,
      walletBalance: _asDouble(json['walletBalance']),
      frozenAmount: _asDouble(json['frozenAmount']),
      custodyRule: json['custodyRule']?.toString() ?? '',
    );
  }

  CaretakerDeposit toEntity() => CaretakerDeposit(
        depositAmount: depositAmount,
        basicRequiredAmount: basicRequiredAmount,
        basicReady: basicReady,
        walletBalance: walletBalance,
        frozenAmount: frozenAmount,
        custodyRule: custodyRule,
      );

  static double _asDouble(Object? value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
