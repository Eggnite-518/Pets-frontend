import 'package:pets/core/network/json_parse.dart';
import 'package:pets/core/utils/image_url_helper.dart';

import '../../domain/entities/order_hall_item.dart';

class OrderHallPetInfoModel extends OrderHallPetInfo {
  const OrderHallPetInfoModel({
    required super.petName,
    required super.petType,
  });

  factory OrderHallPetInfoModel.fromJson(Map<String, dynamic> json) {
    return OrderHallPetInfoModel(
      petName: json['petName']?.toString() ?? '',
      petType: _asInt(json['petType']),
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class OrderHallServiceItemModel extends OrderHallServiceItem {
  const OrderHallServiceItemModel({
    required super.serviceType,
    required super.serviceTypeText,
  });

  factory OrderHallServiceItemModel.fromJson(Map<String, dynamic> json) {
    return OrderHallServiceItemModel(
      serviceType: _asInt(json['serviceType']),
      serviceTypeText: json['serviceTypeText']?.toString() ?? '',
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class OrderHallItemModel extends OrderHallItem {
  const OrderHallItemModel({
    required super.orderId,
    required super.serviceItems,
    required super.totalAmount,
    required super.serviceDate,
    required super.serviceTimeSlot,
    required super.addressDistrict,
    super.latitude,
    super.longitude,
    required super.distanceKm,
    required super.applicationCount,
    required super.isHot,
    super.hasApplied,
    required super.pets,
    required super.createdAt,
    super.ownerNickname,
    super.ownerAvatarUrl,
    super.hardFilterTagDescs,
  });

  factory OrderHallItemModel.fromJson(Map<String, dynamic> json) {
    // 解析 serviceItems 数组
    final rawServices = json['serviceItems'];
    final serviceItems = (rawServices is List)
        ? rawServices
            .map((e) => OrderHallServiceItemModel.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList()
        : <OrderHallServiceItemModel>[];

    // 解析 pets 数组
    final rawPets = json['pets'];
    final pets = (rawPets is List)
        ? rawPets
            .map((e) => OrderHallPetInfoModel.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList()
        : <OrderHallPetInfoModel>[];

    final rawDescs = json['hardFilterTagDescs'];
    final hardFilterTagDescs = (rawDescs is List)
        ? rawDescs.map((e) => e?.toString() ?? '').toList()
        : <String>[];

    return OrderHallItemModel(
      orderId: json['orderId']?.toString() ?? '',
      serviceItems: serviceItems,
      totalAmount: _asInt(json['totalAmount']),
      serviceDate: json['serviceDate']?.toString() ?? '',
      serviceTimeSlot: json['serviceTimeSlot']?.toString() ?? '',
      addressDistrict: json['addressDistrict']?.toString() ?? '',
      latitude: _asDoubleOrNull(json['latitude']),
      longitude: _asDoubleOrNull(json['longitude']),
      distanceKm: _asDouble(json['distanceKm']),
      applicationCount: _asInt(json['applicationCount']),
      isHot: json['isHot'] == true,
      hasApplied: parseApiBool(json['hasApplied']),
      pets: pets,
      createdAt: json['createdAt']?.toString() ?? '',
      ownerNickname: json['ownerNickname']?.toString() ?? '',
      ownerAvatarUrl: normalizeRemoteImageUrl(json['ownerAvatarUrl']?.toString()),
      hardFilterTagDescs: hardFilterTagDescs,
    );
  }

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

  static double? _asDoubleOrNull(Object? value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class OrderHallPageModel extends OrderHallPage {
  const OrderHallPageModel({
    required super.total,
    required super.page,
    required super.pageSize,
    required super.list,
  });

  factory OrderHallPageModel.fromJson(Map<String, dynamic> json) {
    final rawList = json['list'];
    final list = (rawList is List)
        ? rawList
            .map((e) => OrderHallItemModel.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList()
        : <OrderHallItemModel>[];

    return OrderHallPageModel(
      total: _asInt(json['total']),
      page: _asInt(json['page']),
      pageSize: _asInt(json['pageSize']),
      list: list,
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
