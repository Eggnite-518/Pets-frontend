class ProviderDetail {
  final String applicationId;
  final String orderId;
  final int orderStatus;
  final String orderStatusText;
  final List<OrderServiceItem> serviceItems;
  final String totalAmount;
  final double distanceKm;
  final String petName;
  final String petAvatarUrl;
  final String petMemo;
  final String providerId;
  final String providerNickname;
  final String providerAvatarUrl;
  final int creditScore;
  final double rating;
  final int totalOrderCount;
  final double complianceRate;
  final String levelTag;
  final List<String> certLabels;
  final int reviewCount;

  const ProviderDetail({
    required this.applicationId,
    required this.orderId,
    required this.orderStatus,
    required this.orderStatusText,
    required this.serviceItems,
    required this.totalAmount,
    required this.distanceKm,
    required this.petName,
    required this.petAvatarUrl,
    required this.petMemo,
    required this.providerId,
    required this.providerNickname,
    required this.providerAvatarUrl,
    required this.creditScore,
    required this.rating,
    required this.totalOrderCount,
    required this.complianceRate,
    required this.levelTag,
    required this.certLabels,
    required this.reviewCount,
  });
}

class OrderServiceItem {
  final int serviceType;
  final String serviceTypeText;

  const OrderServiceItem({
    required this.serviceType,
    required this.serviceTypeText,
  });
}
