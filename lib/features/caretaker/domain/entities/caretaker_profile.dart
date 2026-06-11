class CaretakerProfile {
  /// 昵称
  final String nickname;

  /// 头像 URL；无图时为 ""
  final String avatarUrl;

  /// 性别：1=男，2=女；后端未设置时为 null
  final int? gender;

  /// 常驻地址文字；未设置时为 null
  final String? residentAddress;

  /// 最大服务半径（千米）；默认 5
  final int serviceRangeKm;

  /// 专业证书认证标签，如 ["实名认证"]（系统生成，只读）
  final List<String> certTags;

  /// 养宠经验/特色标签，如 ["平台认证","10+次服务"]，最多 3 个
  final List<String> certLabels;

  /// 综合评分（0.0–5.0）；系统生成，只读
  final double rating;

  /// 评价总条数；系统生成，只读
  final int reviewCount;

  /// 等级标签，如「金牌宠托师」；系统生成，只读
  final String levelTag;

  const CaretakerProfile({
    required this.nickname,
    required this.avatarUrl,
    this.gender,
    this.residentAddress,
    required this.serviceRangeKm,
    required this.certTags,
    required this.certLabels,
    required this.rating,
    required this.reviewCount,
    required this.levelTag,
  });

  /// 性别展示文案
  String get genderText {
    if (gender == 1) return '男';
    if (gender == 2) return '女';
    return '';
  }
}
