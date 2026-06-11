import 'package:pets/features/owner/domain/entities/order_address.dart';
import 'package:pets/features/owner/domain/entities/order_requirement_tags_data.dart';

class ReorderPrefill {
  final String sourceOrderId;
  final int? addressId;
  final String contactName;
  final String contactPhone;
  final String province;
  final String city;
  final String district;
  final String detailAddress;
  final String addressTag;
  final int serviceType;
  final List<int> petIds;
  final List<String> hardFilterTags;
  final OrderRequirementTagsData requirementTags;
  final String remark;

  const ReorderPrefill({
    required this.sourceOrderId,
    this.addressId,
    this.contactName = '',
    this.contactPhone = '',
    this.province = '',
    this.city = '',
    this.district = '',
    this.detailAddress = '',
    this.addressTag = '',
    this.serviceType = 1,
    this.petIds = const [],
    this.hardFilterTags = const [],
    this.requirementTags = const OrderRequirementTagsData(),
    this.remark = '',
  });

  factory ReorderPrefill.fromJson(Map<String, dynamic> json) {
    return ReorderPrefill(
      sourceOrderId: json['sourceOrderId']?.toString() ?? '',
      addressId: _asIntOrNull(json['addressId']),
      contactName: json['contactName']?.toString() ?? '',
      contactPhone: json['contactPhone']?.toString() ?? '',
      province: json['province']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      detailAddress: json['detailAddress']?.toString() ?? '',
      addressTag: json['addressTag']?.toString() ?? '',
      serviceType: _asInt(json['serviceType'], fallback: 1),
      petIds: (json['petIds'] as List?)
              ?.map((id) => _asInt(id))
              .where((id) => id > 0)
              .toList() ??
          const [],
      hardFilterTags: (json['hardFilterTags'] as List?)
              ?.map((tag) => tag.toString())
              .toList() ??
          const [],
      requirementTags:
          OrderRequirementTagsData.fromJson(json['requirementTags']),
      remark: json['remark']?.toString() ?? '',
    );
  }

  OrderAddress? toOrderAddress() {
    if (addressId == null || addressId! <= 0) {
      return null;
    }
    final fullAddress = '$province$city$district$detailAddress';
    return OrderAddress(
      addressId: addressId!,
      fullAddress: fullAddress,
      contactName: contactName,
      contactPhone: contactPhone,
      addressTag: addressTag,
    );
  }

  /// API serviceType: 1=喂养, 2=遛狗 → UI index: 0/1
  int get uiServiceType => serviceType <= 1 ? 0 : 1;

  static int _asInt(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int? _asIntOrNull(Object? value) {
    if (value == null) return null;
    final parsed = _asInt(value, fallback: -1);
    return parsed > 0 ? parsed : null;
  }
}
