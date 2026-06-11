import '../../domain/entities/my_application.dart';
import 'package:pets/core/utils/image_url_helper.dart';

class MyApplicationModel extends MyApplication {
  const MyApplicationModel({
    required super.applicationId,
    required super.orderId,
    required super.orderStatus,
    required super.orderStatusText,
    required super.serviceType,
    required super.serviceTypeText,
    required super.totalAmount,
    required super.distanceKm,
    required super.serviceDate,
    required super.serviceTimeSlot,
    required super.addressSnapshot,
    required super.petName,
    required super.petAvatarUrl,
  });

  factory MyApplicationModel.fromJson(Map<String, dynamic> json) {
    return MyApplicationModel(
      applicationId: json['applicationId']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      orderStatus: _asInt(json['orderStatus']),
      orderStatusText: json['orderStatusText']?.toString() ?? '',
      serviceType: _asInt(json['serviceType']),
      serviceTypeText: json['serviceTypeText']?.toString() ?? '',
      totalAmount: _asInt(json['totalAmount']),
      distanceKm: _asDouble(json['distanceKm']),
      serviceDate: json['serviceDate']?.toString() ?? '',
      serviceTimeSlot: json['serviceTimeSlot']?.toString() ?? '',
      addressSnapshot: json['addressSnapshot']?.toString() ?? '',
      petName: json['petName']?.toString() ?? '',
      petAvatarUrl: normalizeRemoteImageUrl(json['petAvatarUrl']?.toString()),
    );
  }

  MyApplication toEntity() => MyApplication(
        applicationId: applicationId,
        orderId: orderId,
        orderStatus: orderStatus,
        orderStatusText: orderStatusText,
        serviceType: serviceType,
        serviceTypeText: serviceTypeText,
        totalAmount: totalAmount,
        distanceKm: distanceKm,
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

  static double _asDouble(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}
