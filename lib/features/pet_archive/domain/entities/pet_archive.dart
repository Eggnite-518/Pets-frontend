import 'package:pets/core/domain/pet_profile_tags.dart';

class PetArchive {
  final int petId;
  final int ownerId;
  final String petName;
  final int petType;
  final String defaultReq;
  final String image;
  final PetProfileTags profileTags;

  const PetArchive({
    required this.petId,
    required this.ownerId,
    required this.petName,
    required this.petType,
    required this.defaultReq,
    this.image = '',
    this.profileTags = const PetProfileTags(),
  });
}
