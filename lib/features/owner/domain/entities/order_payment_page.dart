class OrderPaymentPage {
  final String paymentId;
  final String orderId;
  final String payChannel;
  final String payUrl;
  final String expiresAt;

  const OrderPaymentPage({
    required this.paymentId,
    required this.orderId,
    required this.payChannel,
    required this.payUrl,
    required this.expiresAt,
  });
}
