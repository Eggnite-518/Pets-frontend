import '../../domain/entities/order_detail.dart';
import '../../domain/entities/order_requirement_tags_data.dart';
import 'package:pets/core/utils/image_url_helper.dart';

class OrderDetailModel extends OrderDetail {
  const OrderDetailModel({
    required super.orderId,
    required super.serviceDate,
    required super.totalAmount,
    required super.addressSnapshot,
    required super.status,
    required super.pets,
    required super.applications,
    required super.serviceLabel,
    super.requirementTags,
    super.hardFilterTags,
    super.remark,
  });

  factory OrderDetailModel.fromJson(Map<String, dynamic> json) {
    final pets = <OrderDetailPet>[];
    if (json['pets'] is List) {
      for (final e in json['pets'] as List) {
        final m = Map<String, dynamic>.from(e as Map);
        pets.add(
          OrderDetailPet(
            petId: m['petId']?.toString() ?? '',
            petName: m['petName']?.toString() ?? '',
            petType: _toInt(m['petType']),
          ),
        );
      }
    }

    final apps = <OrderDetailApplication>[];
    if (json['applications'] is List) {
      for (final e in json['applications'] as List) {
        final m = Map<String, dynamic>.from(e as Map);
        apps.add(
          OrderDetailApplication(
            applicationId: m['applicationId']?.toString() ?? '',
            providerId: m['providerId']?.toString() ?? '',
            providerNickname: m['providerNickname']?.toString() ?? '',
            providerAvatarUrl: normalizeRemoteImageUrl(
              m['providerAvatarUrl']?.toString(),
            ),
            applyStatus: _toInt(m['applyStatus']),
          ),
        );
      }
    }

    return OrderDetailModel(
      orderId: json['orderId']?.toString() ?? '',
      serviceDate: json['serviceDate']?.toString() ?? '',
      totalAmount: json['totalAmount']?.toString() ?? '0',
      addressSnapshot: json['addressSnapshot']?.toString() ?? '',
      status: _toInt(json['status']),
      pets: pets,
      applications: apps,
      serviceLabel: json['serviceLabel']?.toString() ?? '',
      requirementTags:
          OrderRequirementTagsData.fromJson(json['requirementTags']),
      hardFilterTags: _parseStringList(json['hardFilterTags']),
      remark: json['remark']?.toString() ?? '',
    );
  }

  static List<String> _parseStringList(Object? raw) {
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}
