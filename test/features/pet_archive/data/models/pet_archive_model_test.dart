import 'package:flutter_test/flutter_test.dart';
import 'package:pets/features/pet_archive/data/models/pet_archive_model.dart';

void main() {
  test('parses create response data', () {
    final model = PetArchiveModel.fromJson(
      {
        'petId': 1,
        'ownerId': 100,
        'petName': 'Mimi',
        'petType': 1,
        'defaultReq': 'keep water fresh',
      },
    );

    expect(model.petId, 1);
    expect(model.ownerId, 100);
    expect(model.petName, 'Mimi');
    expect(model.petType, 1);
    expect(model.defaultReq, 'keep water fresh');
  });

  test('parses profile tags from response', () {
    final model = PetArchiveModel.fromJson({
      'petId': 2,
      'ownerId': 100,
      'petName': '龙猫',
      'petType': 3,
      'defaultReq': '更换垫料',
      'profileTags': {
        'weightKg': 0.45,
        'ageGroup': 'ADULT',
        'healthTags': ['MEDICATION'],
      },
    });

    expect(model.petType, 3);
    expect(model.profileTags.weightKg, 0.45);
    expect(model.profileTags.healthTags, ['MEDICATION']);
  });
}
