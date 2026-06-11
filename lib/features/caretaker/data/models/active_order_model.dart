import '../../domain/entities/active_order.dart';
import 'package:pets/core/utils/image_url_helper.dart';

class ActiveOrderModel extends ActiveOrder {
  const ActiveOrderModel({
    required super.orderId,
    required super.orderStatus,
    required super.orderStatusText,
    required super.serviceTypeText,
    required super.serviceDate,
    required super.serviceTimeSlot,
    required super.addressSnapshot,
    required super.petName,
    required super.petAvatarUrl,
  });

  factory ActiveOrderModel.fromJson(Map<String, dynamic> json) {
    return ActiveOrderModel(
      orderId: json['orderId']?.toString() ?? '',
      orderStatus: _asInt(json['orderStatus']),
      orderStatusText: json['orderStatusText']?.toString() ?? '',
      serviceTypeText: json['serviceTypeText']?.toString() ?? '',
      serviceDate: json['serviceDate']?.toString() ?? '',
      serviceTimeSlot: json['serviceTimeSlot']?.toString() ?? '',
      addressSnapshot: json['addressSnapshot']?.toString() ?? '',
      petName: json['petName']?.toString() ?? '',
      petAvatarUrl: normalizeRemoteImageUrl(json['petAvatarUrl']?.toString()),
    );
  }

  ActiveOrder toEntity() => ActiveOrder(
        orderId: orderId,
        orderStatus: orderStatus,
        orderStatusText: orderStatusText,
        serviceTypeText: serviceTypeText,
        serviceDate: serviceDate,
        serviceTimeSlot: serviceTimeSlot,
        addressSnapshot: addressSnapshot,
        petName: petName,
        petAvatarUrl: petAvatarUrl,
      );

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
