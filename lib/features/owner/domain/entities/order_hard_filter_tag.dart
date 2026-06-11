class OrderHardFilterTag {
  static const String femaleOnly = 'FEMALE_ONLY';
  static const String acceptLargeDog = 'ACCEPT_LARGE_DOG';
  static const String medicalFeedingExperience =
      'MEDICAL_FEEDING_EXPERIENCE';

  static const List<String> all = <String>[
    femaleOnly,
    acceptLargeDog,
    medicalFeedingExperience,
  ];

  static const Map<String, String> labels = <String, String>{
    femaleOnly: '仅限女性',
    acceptLargeDog: '接受大型犬',
    medicalFeedingExperience: '具备医疗/喂药经验',
  };

  /// 发单时可选择的安全属性（定向隐私保护）
  static const List<String> ownerSafetySelectable = <String>[
    femaleOnly,
  ];

  /// 发单时可选择的业务属性门槛
  static const List<String> ownerBusinessSelectable = <String>[
    acceptLargeDog,
    medicalFeedingExperience,
  ];

  static const List<String> ownerSelectable = ownerBusinessSelectable;

  static bool isSafetyTag(String tagCode) =>
      ownerSafetySelectable.contains(tagCode);

  static bool isBusinessTag(String tagCode) =>
      ownerBusinessSelectable.contains(tagCode);
}
