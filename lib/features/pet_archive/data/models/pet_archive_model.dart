import 'package:pets/core/domain/pet_profile_tags.dart';
import 'package:pets/core/utils/image_url_helper.dart';

import '../../domain/entities/pet_archive.dart';

class PetArchiveModel extends PetArchive {
  const PetArchiveModel({
    required super.petId,
    required super.ownerId,
    required super.petName,
    required super.petType,
    required super.defaultReq,
    super.image = '',
    super.profileTags = const PetProfileTags(),
  });

  factory PetArchiveModel.fromJson(Map<String, dynamic> json) {
    return PetArchiveModel(
      petId: _asInt(json['petId']),
      ownerId: _asInt(json['ownerId']),
      petName: json['petName']?.toString() ?? '',
      petType: _asInt(json['petType']),
      defaultReq: json['defaultReq']?.toString() ?? '',
      image: normalizeRemoteImageUrl(json['image']?.toString()),
      profileTags: PetProfileTags.fromJson(
        json['profileTags'] is Map
            ? Map<String, dynamic>.from(json['profileTags'] as Map)
            : null,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'petId': petId,
      'ownerId': ownerId,
      'petName': petName,
      'petType': petType,
      'defaultReq': defaultReq,
      'image': image,
      if (!profileTags.isEmpty) 'profileTags': profileTags.toJson(),
    };
  }

  PetArchive toEntity() {
    return PetArchive(
      petId: petId,
      ownerId: ownerId,
      petName: petName,
      petType: petType,
      defaultReq: defaultReq,
      image: image,
      profileTags: profileTags,
    );
  }

  static int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
