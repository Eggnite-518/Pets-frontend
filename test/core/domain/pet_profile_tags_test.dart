import 'package:flutter_test/flutter_test.dart';
import 'package:pets/core/domain/pet_profile_tags.dart';

void main() {
  test('parses profile tags from api response', () {
    final tags = PetProfileTags.fromJson({
      'weightKg': 4.5,
      'ageGroup': 'ADULT',
      'physiologicalStates': ['NEUTERED'],
      'socialFriendliness': 4,
      'aggressionLevel': 'MEDIUM',
      'outdoorBehaviors': ['BOLT_PULL'],
      'indoorBehaviors': ['DESTRUCTIVE'],
      'healthTags': ['ALLERGY', 'DISABILITY'],
    });

    expect(tags.weightKg, 4.5);
    expect(tags.ageGroup, 'ADULT');
    expect(tags.displayLabels, contains('4.50kg'));
    expect(tags.displayLabels, contains('成年期'));
    expect(tags.displayLabels, contains('过敏史'));
    expect(tags.displayLabels, contains('肢体残疾'));
  });
}
