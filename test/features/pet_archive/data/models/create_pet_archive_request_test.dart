import 'package:flutter_test/flutter_test.dart';
import 'package:pets/core/domain/pet_profile_tags.dart';
import 'package:pets/features/pet_archive/data/models/create_pet_archive_request.dart';

void main() {
  test('serializes request with backend field names', () {
    const request = CreatePetArchiveRequest(
      petName: 'Mimi',
      petType: 1,
      defaultReq: 'keep water fresh',
    );

    expect(request.toJson(), {
      'petName': 'Mimi',
      'petType': 1,
      'defaultReq': 'keep water fresh',
    });
  });

  test('serializes profile tags when provided', () {
    const request = CreatePetArchiveRequest(
      petName: '龙猫',
      petType: 3,
      defaultReq: '更换垫料',
      profileTags: PetProfileTags(
        weightKg: 0.45,
        ageGroup: 'ADULT',
        physiologicalStates: ['NEUTERED'],
        socialFriendliness: 3,
        aggressionLevel: 'LOW',
        indoorBehaviors: ['HIDING'],
        healthTags: ['MEDICATION'],
      ),
    );

    expect(request.toJson(), {
      'petName': '龙猫',
      'petType': 3,
      'defaultReq': '更换垫料',
      'profileTags': {
        'weightKg': 0.45,
        'ageGroup': 'ADULT',
        'physiologicalStates': ['NEUTERED'],
        'socialFriendliness': 3,
        'aggressionLevel': 'LOW',
        'indoorBehaviors': ['HIDING'],
        'healthTags': ['MEDICATION'],
      },
    });
  });
}
