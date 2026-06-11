import '../../domain/entities/order_quote.dart';
import 'order_quote_item_model.dart';

class OrderQuoteResponseModel extends OrderQuote {
  const OrderQuoteResponseModel({
    required super.totalAmount,
    required super.priceItems,
  });

  factory OrderQuoteResponseModel.fromJson(Map<String, dynamic> json) {
    final items = <OrderQuoteItemModel>[];
    if (json['priceItems'] is Iterable) {
      for (final item in json['priceItems'] as Iterable) {
        if (item is Map) {
          items.add(OrderQuoteItemModel.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return OrderQuoteResponseModel(
      totalAmount: json['totalAmount']?.toString() ?? '0',
      priceItems: items,
    );
  }

  OrderQuoteResponseModel toEntity() => this;
}
