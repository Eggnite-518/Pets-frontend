import 'package:pets/core/domain/pet_profile_tags.dart';
import 'package:pets/core/network/json_parse.dart';
import 'package:pets/core/utils/image_url_helper.dart';
import 'package:pets/features/owner/domain/entities/order_requirement_tags_data.dart';

import '../../domain/entities/caretaker_order_detail.dart';

class CaretakerOrderDetailModel extends CaretakerOrderDetail {
  const CaretakerOrderDetailModel({
    required super.orderId,
    required super.orderStatus,
    required super.orderStatusText,
    required super.serviceItems,
    required super.serviceDate,
    required super.serviceTimeSlot,
    required super.totalAmount,
    required super.address,
    required super.owner,
    required super.pets,
    required super.serviceNotes,
    super.requirementTags,
    required super.completedNodeTypes,
    required super.checklistNodeTypes,
    required super.createdAt,
    super.distanceKm,
    super.hasApplied,
  });

  factory CaretakerOrderDetailModel.fromJson(Map<String, dynamic> json) {
    return CaretakerOrderDetailModel(
      orderId: json['orderId']?.toString() ?? '',
      orderStatus: _asInt(json['orderStatus']),
      orderStatusText: json['orderStatusText']?.toString() ?? '',
      serviceItems: _parseServiceItems(json['serviceItems']),
      serviceDate: json['serviceDate']?.toString() ?? '',
      serviceTimeSlot: json['serviceTimeSlot']?.toString() ?? '',
      totalAmount: json['totalAmount']?.toString() ?? '0.00',
      address: _parseAddress(json['address']),
      owner: _parseOwner(json['owner']),
      pets: _parsePets(json['pets']),
      serviceNotes: json['serviceNotes']?.toString() ?? '',
      requirementTags:
          OrderRequirementTagsData.fromJson(json['requirementTags']),
      completedNodeTypes: _parseIntList(json['completedNodeTypes']),
      checklistNodeTypes: _parseIntList(json['checklistNodeTypes']),
      createdAt: json['createdAt']?.toString() ?? '',
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      hasApplied: parseApiBool(json['hasApplied']),
    );
  }

  CaretakerOrderDetail toEntity() => CaretakerOrderDetail(
        orderId: orderId,
        orderStatus: orderStatus,
        orderStatusText: orderStatusText,
        serviceItems: serviceItems,
        serviceDate: serviceDate,
        serviceTimeSlot: serviceTimeSlot,
        totalAmount: totalAmount,
        address: address,
        owner: owner,
        pets: pets,
        serviceNotes: serviceNotes,
        requirementTags: requirementTags,
        completedNodeTypes: completedNodeTypes,
        checklistNodeTypes: checklistNodeTypes,
        createdAt: createdAt,
        distanceKm: distanceKm,
        hasApplied: hasApplied,
      );

  static List<OrderServiceItem> _parseServiceItems(Object? raw) {
    if (raw is! List) return [];
    return raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return OrderServiceItem(
        serviceType: _asInt(m['serviceType']),
        serviceTypeText: m['serviceTypeText']?.toString() ?? '',
      );
    }).toList();
  }

  static OrderAddress _parseAddress(Object? raw) {
    if (raw is! Map) return const OrderAddress(fullAddress: '', district: '');
    final m = Map<String, dynamic>.from(raw);
    return OrderAddress(
      fullAddress: m['fullAddress']?.toString() ?? '',
      district: m['district']?.toString() ?? '',
      lat: (m['lat'] as num?)?.toDouble(),
      lng: (m['lng'] as num?)?.toDouble(),
    );
  }

  static OrderOwnerInfo _parseOwner(Object? raw) {
    if (raw is! Map) {
      return const OrderOwnerInfo(nickname: '', avatarUrl: '', phone: '');
    }
    final m = Map<String, dynamic>.from(raw);
    return OrderOwnerInfo(
      nickname: m['nickname']?.toString() ?? '',
      avatarUrl: normalizeRemoteImageUrl(m['avatarUrl']?.toString()),
      phone: m['phone']?.toString() ?? '',
    );
  }

  static List<OrderPetInfo> _parsePets(Object? raw) {
    if (raw is! List) return [];
    return raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return OrderPetInfo(
        petId: m['petId']?.toString() ?? '',
        petName: m['petName']?.toString() ?? '',
        petType: _asInt(m['petType']),
        petTypeText: m['petTypeText']?.toString() ?? '',
        breed: m['breed']?.toString() ?? '',
        ageText: m['ageText']?.toString() ?? '',
        avatarUrl: normalizeRemoteImageUrl(m['avatarUrl']?.toString()),
        careNotes: m['careNotes']?.toString() ?? '',
        profileTags: _parseProfileTags(m['profileTags']),
      );
    }).toList();
  }

  static List<int> _parseIntList(Object? raw) {
    if (raw is! List) return [];
    return raw.map((e) => _asInt(e)).toList();
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static PetProfileTags _parseProfileTags(Object? raw) {
    if (raw is! Map) return const PetProfileTags();
    return PetProfileTags.fromJson(Map<String, dynamic>.from(raw));
  }
}
