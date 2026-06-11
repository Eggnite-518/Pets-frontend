import 'package:pets/features/owner/domain/entities/order_requirement_tags_data.dart';

class AddressFamilySop {
  final int addressId;
  final bool hasSop;
  final OrderRequirementTagsData requirementTags;
  final List<String> hardFilterTags;
  final String remark;
  final String? updatedAt;

  const AddressFamilySop({
    required this.addressId,
    required this.hasSop,
    this.requirementTags = const OrderRequirementTagsData(),
    this.hardFilterTags = const [],
    this.remark = '',
    this.updatedAt,
  });

  factory AddressFamilySop.fromJson(Map<String, dynamic> json) {
    return AddressFamilySop(
      addressId: _asInt(json['addressId']),
      hasSop: json['hasSop'] == true,
      requirementTags:
          OrderRequirementTagsData.fromJson(json['requirementTags']),
      hardFilterTags: (json['hardFilterTags'] as List?)
              ?.map((tag) => tag.toString())
              .toList() ??
          const [],
      remark: json['remark']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString(),
    );
  }

  Map<String, dynamic> toSaveBody({
    required OrderRequirementTagsData requirementTags,
    required List<String> hardFilterTags,
    required String remark,
  }) {
    final body = <String, dynamic>{};
    if (!requirementTags.isEmpty) {
      body['requirementTags'] = requirementTags.toJson();
    }
    if (hardFilterTags.isNotEmpty) {
      body['hardFilterTags'] = hardFilterTags;
    }
    if (remark.trim().isNotEmpty) {
      body['remark'] = remark.trim();
    }
    return body;
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
