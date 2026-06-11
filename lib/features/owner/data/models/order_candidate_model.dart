import '../../domain/entities/order_candidate.dart';
import 'package:pets/core/utils/image_url_helper.dart';

class OrderCandidateItemModel extends OrderCandidateItem {
  const OrderCandidateItemModel({
    required super.applicationId,
    required super.providerId,
    required super.providerNickname,
    required super.providerAvatarUrl,
    required super.applyStatus,
    required super.applyStatusDesc,
    required super.distanceKm,
    required super.rating,
    required super.totalOrderCount,
    required super.creditScore,
  });

  factory OrderCandidateItemModel.fromJson(Map<String, dynamic> json) {
    return OrderCandidateItemModel(
      applicationId: json['applicationId']?.toString() ?? '',
      providerId: json['providerId']?.toString() ?? '',
      providerNickname: json['providerNickname']?.toString() ?? '',
      providerAvatarUrl: normalizeRemoteImageUrl(
        json['providerAvatarUrl']?.toString(),
      ),
      applyStatus: _toInt(json['applyStatus']),
      applyStatusDesc: json['applyStatusDesc']?.toString() ?? '',
      distanceKm: _toDoubleOrNull(json['distanceKm']),
      rating: _toDoubleOrNull(json['rating']),
      totalOrderCount: _toInt(json['totalOrderCount']),
      creditScore: _toInt(json['creditScore']),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _toDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class OrderCandidateListModel extends OrderCandidateList {
  const OrderCandidateListModel({
    required super.orderId,
    required super.sortBy,
    required super.sortByDesc,
    required super.candidates,
  });

  factory OrderCandidateListModel.fromJson(Map<String, dynamic> json) {
    final candidates = <OrderCandidateItemModel>[];
    if (json['candidates'] is List) {
      for (final e in json['candidates'] as List) {
        candidates.add(
          OrderCandidateItemModel.fromJson(Map<String, dynamic>.from(e as Map)),
        );
      }
    }

    return OrderCandidateListModel(
      orderId: json['orderId']?.toString() ?? '',
      sortBy: json['sortBy']?.toString() ?? '',
      sortByDesc: json['sortByDesc']?.toString() ?? '',
      candidates: candidates,
    );
  }
}
