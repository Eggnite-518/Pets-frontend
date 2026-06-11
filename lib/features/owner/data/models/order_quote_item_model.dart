import '../../domain/entities/order_quote_item.dart';

class OrderQuoteItemModel extends OrderQuoteItem {
  const OrderQuoteItemModel({
    required super.itemName,
    required super.amount,
    required super.quantity,
    required super.remark,
  });

  factory OrderQuoteItemModel.fromJson(Map<String, dynamic> json) {
    return OrderQuoteItemModel(
      itemName: json['itemName']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '0',
      quantity: json['quantity'] is int ? json['quantity'] as int : int.tryParse(json['quantity']?.toString() ?? '') ?? 0,
      remark: json['remark']?.toString() ?? '',
    );
  }
}
