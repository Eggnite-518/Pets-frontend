import '../../domain/entities/caretaker_profile.dart';
import 'package:pets/core/utils/image_url_helper.dart';

class CaretakerProfileModel extends CaretakerProfile {
  const CaretakerProfileModel({
    required super.nickname,
    required super.avatarUrl,
    super.gender,
    super.residentAddress,
    required super.serviceRangeKm,
    required super.certTags,
    required super.certLabels,
    required super.rating,
    required super.reviewCount,
    required super.levelTag,
  });

  factory CaretakerProfileModel.fromJson(Map<String, dynamic> json) {
    return CaretakerProfileModel(
      nickname: json['nickname']?.toString() ?? '',
      avatarUrl: normalizeRemoteImageUrl(json['avatarUrl']?.toString()),
      gender: _asIntOrNull(json['gender']),
      residentAddress: json['residentAddress']?.toString(),
      serviceRangeKm: _asInt(json['serviceRangeKm'], fallback: 5),
      certTags: _asList(json['certTags']),
      certLabels: _asList(json['certLabels']),
      rating: _asDouble(json['rating']),
      reviewCount: _asInt(json['reviewCount']),
      levelTag: json['levelTag']?.toString() ?? '',
    );
  }

  CaretakerProfile toEntity() => CaretakerProfile(
        nickname: nickname,
        avatarUrl: avatarUrl,
        gender: gender,
        residentAddress: residentAddress,
        serviceRangeKm: serviceRangeKm,
        certTags: certTags,
        certLabels: certLabels,
        rating: rating,
        reviewCount: reviewCount,
        levelTag: levelTag,
      );

  static int? _asIntOrNull(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static int _asInt(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _asDouble(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  static List<String> _asList(Object? value) {
    if (value is List) return value.map((e) => e?.toString() ?? '').toList();
    return [];
  }
}
