class OrderAddress {
  final int addressId;
  final String fullAddress;
  final String contactName;
  final String contactPhone;
  final String addressTag;

  const OrderAddress({
    required this.addressId,
    required this.fullAddress,
    required this.contactName,
    required this.contactPhone,
    required this.addressTag,
  });

  factory OrderAddress.fromMap(Map<String, dynamic> map) {
    return OrderAddress(
      addressId: map['addressId'] is int ? map['addressId'] as int : int.tryParse(map['addressId']?.toString() ?? '') ?? 0,
      fullAddress: map['fullAddress']?.toString() ?? '',
      contactName: map['contactName']?.toString() ?? '',
      contactPhone: map['contactPhone']?.toString() ?? '',
      addressTag: map['addressTag']?.toString() ?? '',
    );
  }
}
