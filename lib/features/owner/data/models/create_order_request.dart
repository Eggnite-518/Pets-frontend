class CreateOrderRequest {
  final int serviceType;
  final List<String> petIds;  // 改成 String 数组
  final String addressId;  // 改成必填 String
  final String serviceDate;
  final String serviceStartTime;
  final String serviceEndTime;
  final String finalAmount;
  final String? remark;  // 改成可选
  final List<String>? hardFilterTags;
  final Map<String, dynamic>? requirementTags;

  const CreateOrderRequest({
    required this.serviceType,
    required this.petIds,
    required this.addressId,
    required this.serviceDate,
    required this.serviceStartTime,
    required this.serviceEndTime,
    required this.finalAmount,
    this.remark,
    this.hardFilterTags,
    this.requirementTags,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'serviceType': serviceType,
      'petIds': petIds,
      'addressId': addressId,
      'serviceDate': serviceDate,
      'serviceStartTime': serviceStartTime,
      'serviceEndTime': serviceEndTime,
      'finalAmount': finalAmount,
    };

    if (remark != null && remark!.isNotEmpty) {
      json['remark'] = remark;
    }
    if (hardFilterTags != null && hardFilterTags!.isNotEmpty) {
      json['hardFilterTags'] = hardFilterTags;
    }
    if (requirementTags != null && requirementTags!.isNotEmpty) {
      json['requirementTags'] = requirementTags;
    }
    return json;
  }
}
