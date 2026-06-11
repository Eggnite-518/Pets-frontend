import 'package:pets/core/domain/pet_profile_tags.dart';

class CreatePetArchiveRequest {
  final String petName;
  final int petType;
  final String defaultReq;
  final String? image;
  final PetProfileTags? profileTags;

  const CreatePetArchiveRequest({
    required this.petName,
    required this.petType,
    required this.defaultReq,
    this.image,
    this.profileTags,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'petName': petName,
      'petType': petType,
      'defaultReq': defaultReq,
    };
    if (image != null && image!.trim().isNotEmpty) {
      json['image'] = image!.trim();
    }
    if (profileTags != null && !profileTags!.isEmpty) {
      json['profileTags'] = profileTags!.toJson();
    }
    return json;
  }
}
