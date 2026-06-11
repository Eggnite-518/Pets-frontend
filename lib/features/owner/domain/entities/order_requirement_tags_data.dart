class OrderRequirementTagsData {
  final List<String> tags;
  final String accessNote;
  final String emergencyContactName;
  final String emergencyContactPhone;

  const OrderRequirementTagsData({
    this.tags = const [],
    this.accessNote = '',
    this.emergencyContactName = '',
    this.emergencyContactPhone = '',
  });

  bool get isEmpty =>
      tags.isEmpty &&
      accessNote.trim().isEmpty &&
      emergencyContactName.trim().isEmpty &&
      emergencyContactPhone.trim().isEmpty;

  bool get isNotEmpty => !isEmpty;

  factory OrderRequirementTagsData.fromJson(Object? raw) {
    if (raw is! Map) {
      return const OrderRequirementTagsData();
    }
    final json = Map<String, dynamic>.from(raw);
    return OrderRequirementTagsData(
      tags: (json['tags'] as List?)
              ?.map((tag) => tag.toString())
              .where((tag) => tag.isNotEmpty)
              .toList() ??
          const [],
      accessNote: json['accessNote']?.toString() ?? '',
      emergencyContactName: json['emergencyContactName']?.toString() ?? '',
      emergencyContactPhone: json['emergencyContactPhone']?.toString() ?? '',
    );
  }

  OrderRequirementTagsData copyWith({
    List<String>? tags,
    String? accessNote,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) {
    return OrderRequirementTagsData(
      tags: tags ?? this.tags,
      accessNote: accessNote ?? this.accessNote,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (tags.isNotEmpty) {
      json['tags'] = tags;
    }
    if (accessNote.trim().isNotEmpty) {
      json['accessNote'] = accessNote.trim();
    }
    if (emergencyContactName.trim().isNotEmpty) {
      json['emergencyContactName'] = emergencyContactName.trim();
    }
    if (emergencyContactPhone.trim().isNotEmpty) {
      json['emergencyContactPhone'] = emergencyContactPhone.trim();
    }
    return json;
  }
}
