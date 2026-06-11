/// 宠物类型枚举，与后端 `PetTypeEnum` 对齐。
class PetType {
  static const int cat = 1;
  static const int dog = 2;
  static const int exotic = 3;

  static const List<PetTypeOption> selectableOptions = [
    PetTypeOption(cat, '猫咪'),
    PetTypeOption(dog, '狗狗'),
    PetTypeOption(exotic, '异宠'),
  ];

  static String label(int petType) {
    return switch (petType) {
      cat => '猫咪',
      dog => '狗狗',
      exotic => '异宠',
      _ => '未知',
    };
  }
}

class PetTypeOption {
  final int value;
  final String label;

  const PetTypeOption(this.value, this.label);
}
