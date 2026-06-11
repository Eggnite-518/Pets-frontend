class OrderHallPetInfo {
  final String petName;
  final int petType;

  const OrderHallPetInfo({
    required this.petName,
    required this.petType,
  });
}

/// 单个服务项（一单可有多种服务）
class OrderHallServiceItem {
  final int serviceType;
  final String serviceTypeText;

  const OrderHallServiceItem({
    required this.serviceType,
    required this.serviceTypeText,
  });
}

class OrderHallItem {
  final String orderId;
  /// 一单对应的所有服务类型（至少一项）
  final List<OrderHallServiceItem> serviceItems;
  final int totalAmount;
  final String serviceDate;
  final String serviceTimeSlot;
  final String addressDistrict;
  /// 高德坐标系（GCJ-02）；后端暂未支持时为 null
  final double? latitude;
  final double? longitude;
  final double distanceKm;
  final int applicationCount;
  final bool isHot;
  /// 当前宠托师是否已报名该订单
  final bool hasApplied;
  final List<OrderHallPetInfo> pets;
  final String createdAt;
  final String ownerNickname;
  final String? ownerAvatarUrl;
  /// 硬性门槛标签描述，如 ["仅限女性宠托师"]；无门槛时为空列表
  final List<String> hardFilterTagDescs;

  const OrderHallItem({
    required this.orderId,
    required this.serviceItems,
    required this.totalAmount,
    required this.serviceDate,
    required this.serviceTimeSlot,
    required this.addressDistrict,
    this.latitude,
    this.longitude,
    required this.distanceKm,
    required this.applicationCount,
    required this.isHot,
    this.hasApplied = false,
    required this.pets,
    required this.createdAt,
    this.ownerNickname = '',
    this.ownerAvatarUrl,
    this.hardFilterTagDescs = const [],
  });

  /// 供展示用：所有服务类型文案，用「、」连接，如「上门喂猫、上门遛狗」
  String get serviceTypeSummary =>
      serviceItems.map((s) => s.serviceTypeText).join('、');
}

class OrderHallPage {
  final int total;
  final int page;
  final int pageSize;
  final List<OrderHallItem> list;

  const OrderHallPage({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.list,
  });
}
