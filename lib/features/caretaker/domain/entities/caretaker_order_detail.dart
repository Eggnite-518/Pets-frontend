import 'package:pets/core/domain/pet_profile_tags.dart';
import 'package:pets/features/owner/domain/entities/order_requirement_tags_data.dart';

class CaretakerOrderDetail {
  final String orderId;

  /// 3=待履约，4=履约中，5=待宠主确认，6=已完成
  final int orderStatus;
  final String orderStatusText;

  final List<OrderServiceItem> serviceItems;
  final String serviceDate;
  final String serviceTimeSlot;

  /// 保留两位小数字符串，如 "120.00"
  final String totalAmount;

  final OrderAddress address;
  final OrderOwnerInfo owner;
  final List<OrderPetInfo> pets;

  /// 宠主下单时填写的特殊说明
  final String serviceNotes;

  /// 物品引导 / 环境交代 / 视频打卡 / 服务选项等需求标签
  final OrderRequirementTagsData requirementTags;

  /// 已完成的打卡节点 nodeType 列表
  final List<int> completedNodeTypes;

  /// 当前订单允许展示的打卡节点列表
  final List<int> checklistNodeTypes;

  final String createdAt;

  /// 宠托师常驻地址到订单地址的直线距离（km），null 表示无法计算
  final double? distanceKm;

  /// 当前宠托师是否已报名（仅悬赏中订单有意义）
  final bool hasApplied;

  const CaretakerOrderDetail({
    required this.orderId,
    required this.orderStatus,
    required this.orderStatusText,
    required this.serviceItems,
    required this.serviceDate,
    required this.serviceTimeSlot,
    required this.totalAmount,
    required this.address,
    required this.owner,
    required this.pets,
    required this.serviceNotes,
    this.requirementTags = const OrderRequirementTagsData(),
    required this.completedNodeTypes,
    required this.checklistNodeTypes,
    required this.createdAt,
    this.distanceKm,
    this.hasApplied = false,
  });
}

class OrderServiceItem {
  final int serviceType;
  final String serviceTypeText;
  const OrderServiceItem({required this.serviceType, required this.serviceTypeText});
}

class OrderAddress {
  /// 完整地址（含楼栋门牌），用于导航
  final String fullAddress;
  final String district;
  final double? lat;
  final double? lng;
  const OrderAddress({
    required this.fullAddress,
    required this.district,
    this.lat,
    this.lng,
  });
}

class OrderOwnerInfo {
  final String nickname;
  final String avatarUrl;
  /// 脱敏后的手机号，如 "138****8888"
  final String phone;
  const OrderOwnerInfo({
    required this.nickname,
    required this.avatarUrl,
    required this.phone,
  });
}

class OrderPetInfo {
  final String petId;
  final String petName;
  final int petType;
  final String petTypeText;
  final String breed;
  final String ageText;
  final String avatarUrl;
  /// 护理备注
  final String careNotes;
  final PetProfileTags profileTags;
  const OrderPetInfo({
    required this.petId,
    required this.petName,
    required this.petType,
    required this.petTypeText,
    required this.breed,
    required this.ageText,
    required this.avatarUrl,
    required this.careNotes,
    this.profileTags = const PetProfileTags(),
  });
}
