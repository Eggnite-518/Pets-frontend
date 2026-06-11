import 'package:pets/features/owner/domain/entities/order_requirement_tags_data.dart';

class OrderDetail {
  final String orderId;
  final String serviceDate;
  final String totalAmount;
  final String addressSnapshot;
  final int status;
  final List<OrderDetailPet> pets;
  final List<OrderDetailApplication> applications;
  final String serviceLabel;
  final OrderRequirementTagsData requirementTags;
  final List<String> hardFilterTags;
  final String remark;

  const OrderDetail({
    required this.orderId,
    required this.serviceDate,
    required this.totalAmount,
    required this.addressSnapshot,
    required this.status,
    required this.pets,
    required this.applications,
    required this.serviceLabel,
    this.requirementTags = const OrderRequirementTagsData(),
    this.hardFilterTags = const [],
    this.remark = '',
  });

  bool get hasServiceRequirements =>
      requirementTags.isNotEmpty ||
      hardFilterTags.isNotEmpty ||
      remark.trim().isNotEmpty;
}

class OrderDetailPet {
  final String petId;
  final String petName;
  final int petType;

  const OrderDetailPet({required this.petId, required this.petName, required this.petType});
}

class OrderDetailApplication {
  final String applicationId;
  final String providerId;
  final String providerNickname;
  final String providerAvatarUrl;
  final int applyStatus;

  const OrderDetailApplication({
    required this.applicationId,
    required this.providerId,
    required this.providerNickname,
    required this.providerAvatarUrl,
    required this.applyStatus,
  });
}
