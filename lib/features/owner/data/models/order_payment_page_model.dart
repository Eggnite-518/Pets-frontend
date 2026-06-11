import '../../domain/entities/order_payment_page.dart';

class OrderPaymentPageModel extends OrderPaymentPage {
  const OrderPaymentPageModel({
    required super.paymentId,
    required super.orderId,
    required super.payChannel,
    required super.payUrl,
    required super.expiresAt,
  });

  factory OrderPaymentPageModel.fromJson(Map<String, dynamic> json) {
    return OrderPaymentPageModel(
      paymentId: json['paymentId']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      payChannel: json['payChannel']?.toString() ?? '',
      payUrl: json['payUrl']?.toString() ?? '',
      expiresAt: json['expiresAt']?.toString() ?? '',
    );
  }
}
