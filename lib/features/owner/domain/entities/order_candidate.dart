class OrderCandidateList {
  final String orderId;
  final String sortBy;
  final String sortByDesc;
  final List<OrderCandidateItem> candidates;

  const OrderCandidateList({
    required this.orderId,
    required this.sortBy,
    required this.sortByDesc,
    required this.candidates,
  });
}

class OrderCandidateItem {
  final String applicationId;
  final String providerId;
  final String providerNickname;
  final String providerAvatarUrl;
  final int applyStatus;
  final String applyStatusDesc;
  final double? distanceKm;
  final double? rating;
  final int totalOrderCount;
  final int creditScore;

  const OrderCandidateItem({
    required this.applicationId,
    required this.providerId,
    required this.providerNickname,
    required this.providerAvatarUrl,
    required this.applyStatus,
    required this.applyStatusDesc,
    required this.distanceKm,
    required this.rating,
    required this.totalOrderCount,
    required this.creditScore,
  });
}
