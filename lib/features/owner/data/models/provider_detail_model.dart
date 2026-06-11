import '../../domain/entities/provider_detail.dart';
import 'package:pets/core/utils/image_url_helper.dart';

class ProviderDetailModel extends ProviderDetail {
  const ProviderDetailModel({
    required super.applicationId,
    required super.orderId,
    required super.orderStatus,
    required super.orderStatusText,
    required super.serviceItems,
    required super.totalAmount,
    required super.distanceKm,
    required super.petName,
    required super.petAvatarUrl,
    required super.petMemo,
    required super.providerId,
    required super.providerNickname,
    required super.providerAvatarUrl,
    required super.creditScore,
    required super.rating,
    required super.totalOrderCount,
    required super.complianceRate,
    required super.levelTag,
    required super.certLabels,
    required super.reviewCount,
    required super.punctualityAvg,
    required super.professionalAvg,
  });

  factory ProviderDetailModel.fromJson(Map<String, dynamic> json) {
    final serviceItems = <OrderServiceItem>[];
    if (json['serviceItems'] is List) {
      for (final item in json['serviceItems'] as List) {
        final parsed = Map<String, dynamic>.from(item as Map);
        serviceItems.add(OrderServiceItem(
          serviceType: _toInt(parsed['serviceType']),
          serviceTypeText: parsed['serviceTypeText']?.toString() ?? '',
        ));
      }
    }

    return ProviderDetailModel(
      applicationId: json['applicationId']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      orderStatus: _toInt(json['orderStatus']),
      orderStatusText: json['orderStatusText']?.toString() ?? '',
      serviceItems: serviceItems,
      totalAmount: json['totalAmount']?.toString() ?? '0',
      distanceKm: _toDouble(json['distanceKm']),
      petName: json['petName']?.toString() ?? '',
      petAvatarUrl: normalizeRemoteImageUrl(json['petAvatarUrl']?.toString()),
      petMemo: json['petMemo']?.toString() ?? '',
      providerId: json['providerId']?.toString() ?? '',
      providerNickname: json['providerNickname']?.toString() ?? '',
      providerAvatarUrl: normalizeRemoteImageUrl(
        json['providerAvatarUrl']?.toString(),
      ),
      creditScore: _toInt(json['creditScore']),
      rating: _toDouble(json['rating']),
      totalOrderCount: _toInt(json['totalOrderCount']),
      complianceRate: _toDouble(json['complianceRate']),
      levelTag: json['levelTag']?.toString() ?? '',
      certLabels: (json['certLabels'] is List)
          ? (json['certLabels'] as List)
              .map((e) => e?.toString() ?? '')
              .toList()
          : const <String>[],
      reviewCount: _toInt(json['reviewCount']),
      punctualityAvg: _toDouble(json['punctualityAvg']),
      professionalAvg: _toDouble(json['professionalAvg']),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}
