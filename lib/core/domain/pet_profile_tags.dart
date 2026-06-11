class PetProfileTags {
  final double? weightKg;
  final String? ageGroup;
  final List<String> physiologicalStates;
  final int? socialFriendliness;
  final String? aggressionLevel;
  final List<String> outdoorBehaviors;
  final List<String> indoorBehaviors;
  final List<String> healthTags;

  const PetProfileTags({
    this.weightKg,
    this.ageGroup,
    this.physiologicalStates = const [],
    this.socialFriendliness,
    this.aggressionLevel,
    this.outdoorBehaviors = const [],
    this.indoorBehaviors = const [],
    this.healthTags = const [],
  });

  bool get isEmpty =>
      weightKg == null &&
      ageGroup == null &&
      physiologicalStates.isEmpty &&
      socialFriendliness == null &&
      aggressionLevel == null &&
      outdoorBehaviors.isEmpty &&
      indoorBehaviors.isEmpty &&
      healthTags.isEmpty;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (weightKg != null) json['weightKg'] = weightKg;
    if (ageGroup != null) json['ageGroup'] = ageGroup;
    if (physiologicalStates.isNotEmpty) {
      json['physiologicalStates'] = physiologicalStates;
    }
    if (socialFriendliness != null) {
      json['socialFriendliness'] = socialFriendliness;
    }
    if (aggressionLevel != null) json['aggressionLevel'] = aggressionLevel;
    if (outdoorBehaviors.isNotEmpty) {
      json['outdoorBehaviors'] = outdoorBehaviors;
    }
    if (indoorBehaviors.isNotEmpty) {
      json['indoorBehaviors'] = indoorBehaviors;
    }
    if (healthTags.isNotEmpty) json['healthTags'] = healthTags;
    return json;
  }

  factory PetProfileTags.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PetProfileTags();
    return PetProfileTags(
      weightKg: _toDouble(json['weightKg']),
      ageGroup: json['ageGroup']?.toString(),
      physiologicalStates: _asStringList(json['physiologicalStates']),
      socialFriendliness: _toInt(json['socialFriendliness']),
      aggressionLevel: json['aggressionLevel']?.toString(),
      outdoorBehaviors: _asStringList(json['outdoorBehaviors']),
      indoorBehaviors: _asStringList(json['indoorBehaviors']),
      healthTags: _asStringList(json['healthTags']),
    );
  }

  List<String> get displayLabels {
    final labels = <String>[];
    if (weightKg != null) labels.add('${weightKg!.toStringAsFixed(2)}kg');
    if (ageGroup != null) {
      labels.add(PetAgeGroup.label(ageGroup!));
    }
    labels.addAll(
      physiologicalStates.map(PetPhysiologicalState.label),
    );
    if (socialFriendliness != null) {
      labels.add('社交 $socialFriendliness 星');
    }
    if (aggressionLevel != null) {
      labels.add('攻击性 ${PetAggressionLevel.label(aggressionLevel!)}');
    }
    labels.addAll(outdoorBehaviors.map(PetOutdoorBehavior.label));
    labels.addAll(indoorBehaviors.map(PetIndoorBehavior.label));
    labels.addAll(healthTags.map(PetHealthTag.label));
    return labels;
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static List<String> _asStringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((e) => e.toString()).toList();
  }
}

class PetTagOption {
  final String code;
  final String label;
  const PetTagOption(this.code, this.label);
}

class PetAgeGroup {
  static const String infant = 'INFANT';
  static const String juvenile = 'JUVENILE';
  static const String adult = 'ADULT';
  static const String senior = 'SENIOR';

  static const List<PetTagOption> options = [
    PetTagOption(infant, '幼年期'),
    PetTagOption(juvenile, '青年期'),
    PetTagOption(adult, '成年期'),
    PetTagOption(senior, '老年期'),
  ];

  static String label(String code) =>
      options.firstWhere((o) => o.code == code, orElse: () => PetTagOption(code, code)).label;
}

class PetPhysiologicalState {
  static const String neutered = 'NEUTERED';
  static const String inHeat = 'IN_HEAT';

  static const List<PetTagOption> options = [
    PetTagOption(neutered, '已绝育'),
    PetTagOption(inHeat, '发情期'),
  ];

  static String label(String code) =>
      options.firstWhere((o) => o.code == code, orElse: () => PetTagOption(code, code)).label;
}

class PetAggressionLevel {
  static const String low = 'LOW';
  static const String medium = 'MEDIUM';
  static const String high = 'HIGH';

  static const List<PetTagOption> options = [
    PetTagOption(low, '低'),
    PetTagOption(medium, '中'),
    PetTagOption(high, '高'),
  ];

  static String label(String code) =>
      options.firstWhere((o) => o.code == code, orElse: () => PetTagOption(code, code)).label;
}

class PetOutdoorBehavior {
  static const String boltPull = 'BOLT_PULL';
  static const String eatsGrass = 'EATS_GRASS';

  static const List<PetTagOption> options = [
    PetTagOption(boltPull, '易爆冲'),
    PetTagOption(eatsGrass, '食草'),
  ];

  static String label(String code) =>
      options.firstWhere((o) => o.code == code, orElse: () => PetTagOption(code, code)).label;
}

class PetIndoorBehavior {
  static const String destructive = 'DESTRUCTIVE';
  static const String hiding = 'HIDING';

  static const List<PetTagOption> options = [
    PetTagOption(destructive, '易拆家'),
    PetTagOption(hiding, '易躲藏'),
  ];

  static String label(String code) =>
      options.firstWhere((o) => o.code == code, orElse: () => PetTagOption(code, code)).label;
}

class PetHealthTag {
  static const String medication = 'MEDICATION';
  static const String allergy = 'ALLERGY';
  static const String disability = 'DISABILITY';

  static const List<PetTagOption> options = [
    PetTagOption(medication, '用药需求'),
    PetTagOption(allergy, '过敏史'),
    PetTagOption(disability, '肢体残疾'),
  ];

  static String label(String code) =>
      options.firstWhere((o) => o.code == code, orElse: () => PetTagOption(code, code)).label;
}
