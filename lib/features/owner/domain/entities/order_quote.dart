import 'order_quote_item.dart';

class OrderQuote {
  final String totalAmount;
  final List<OrderQuoteItem> priceItems;

  const OrderQuote({
    required this.totalAmount,
    required this.priceItems,
  });
}
