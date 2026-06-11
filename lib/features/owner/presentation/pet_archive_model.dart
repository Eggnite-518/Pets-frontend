import 'package:pets/core/domain/pet_profile_tags.dart';
import 'package:pets/core/domain/pet_type.dart';
import 'package:pets/core/utils/image_url_helper.dart';

class PetArchiveModel {
  final int petId;
  final int ownerId;
  final String petName;
  final int petType;
  final String defaultReq;
  final String image;
  final PetProfileTags profileTags;

  const PetArchiveModel({
    required this.petId,
    required this.ownerId,
    required this.petName,
    required this.petType,
    required this.defaultReq,
    required this.image,
    this.profileTags = const PetProfileTags(),
  });

  factory PetArchiveModel.fromJson(Map<String, dynamic> json) {
    return PetArchiveModel(
      petId: _toInt(json['petId']),
      ownerId: _toInt(json['ownerId']),
      petName: json['petName']?.toString() ?? '',
      petType: _toInt(json['petType']),
      defaultReq: json['defaultReq']?.toString() ?? '',
      image: normalizeRemoteImageUrl(json['image']?.toString()),
      profileTags: PetProfileTags.fromJson(
        json['profileTags'] is Map
            ? Map<String, dynamic>.from(json['profileTags'] as Map)
            : null,
      ),
    );
  }

  Map<String, dynamic> toRequestBody() {
    return {
      'petName': petName,
      'petType': petType,
      'defaultReq': defaultReq,
      'image': image,
      if (!profileTags.isEmpty) 'profileTags': profileTags.toJson(),
    };
  }

  String get typeLabel => PetType.label(petType);

  String get displayImagePath {
    if (image.trim().isEmpty) {
      return 'assets/image/cat.webp';
    }
    return image;
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
