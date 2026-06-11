class OrderQuoteRequest {
  final List<String> petIds;  // 改成 String 数组
  final int serviceType;
  final String addressId;  // 改成必填 String
  final String serviceDate;
  final String serviceStartTime;
  final String serviceEndTime;
  final String? remark;  // 改成可选
  final List<String>? hardFilterTags;
  final Map<String, dynamic>? requirementTags;

  OrderQuoteRequest({
    required this.petIds,
    required this.serviceType,
    required this.addressId,
    required this.serviceDate,
    required this.serviceStartTime,
    required this.serviceEndTime,
    this.remark,
    this.hardFilterTags,
    this.requirementTags,
  });

  Map<String, dynamic> toJson() {
    return {
      'petIds': petIds,
      'serviceType': serviceType,
      'addressId': addressId,
      'serviceDate': serviceDate,
      'serviceStartTime': serviceStartTime,
      'serviceEndTime': serviceEndTime,
      if (remark != null && remark!.isNotEmpty) 'remark': remark,
      if (hardFilterTags != null && hardFilterTags!.isNotEmpty)
        'hardFilterTags': hardFilterTags,
      if (requirementTags != null && requirementTags!.isNotEmpty)
        'requirementTags': requirementTags,
    };
  }
}
