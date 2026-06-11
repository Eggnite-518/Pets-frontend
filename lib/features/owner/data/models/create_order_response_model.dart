import '../../domain/entities/order_create_result.dart';

class CreateOrderResponseModel extends OrderCreateResult {
  const CreateOrderResponseModel({
    required super.orderId,
    required super.orderStatus,
    required super.orderStatusText,
    required super.totalAmount,
    required super.serviceType,
    required super.serviceTypeText,
    required super.serviceDate,
    required super.serviceStartTime,
    required super.serviceEndTime,
    required super.createdAt,
  });

  factory CreateOrderResponseModel.fromJson(Map<String, dynamic> json) {
    return CreateOrderResponseModel(
      orderId: json['orderId']?.toString() ?? '',
      orderStatus: json['orderStatus'] is int ? json['orderStatus'] as int : int.tryParse(json['orderStatus']?.toString() ?? '') ?? 0,
      orderStatusText: json['orderStatusText']?.toString() ?? '',
      totalAmount: json['totalAmount']?.toString() ?? '',
      serviceType: json['serviceType'] is int ? json['serviceType'] as int : int.tryParse(json['serviceType']?.toString() ?? '') ?? 0,
      serviceTypeText: json['serviceTypeText']?.toString() ?? '',
      serviceDate: json['serviceDate']?.toString() ?? '',
      serviceStartTime: json['serviceStartTime']?.toString() ?? '',
      serviceEndTime: json['serviceEndTime']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }

  CreateOrderResponseModel toEntity() => this;
}
