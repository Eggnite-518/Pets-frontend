import '../../domain/entities/caretaker_wallet.dart';

class CaretakerWalletModel extends CaretakerWallet {
  const CaretakerWalletModel({required super.balance});

  factory CaretakerWalletModel.fromJson(Map<String, dynamic> json) {
    return CaretakerWalletModel(
      balance: json['balance']?.toString() ?? '0.00',
    );
  }

  CaretakerWallet toEntity() => CaretakerWallet(balance: balance);
}
