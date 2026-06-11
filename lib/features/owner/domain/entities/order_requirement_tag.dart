class OrderRequirementTag {
  // 物品引导
  static const String foodBowlLocation = 'FOOD_BOWL_LOCATION';
  static const String mainFoodStorage = 'MAIN_FOOD_STORAGE';
  static const String waterBowlLocation = 'WATER_BOWL_LOCATION';
  static const String litterBoxLocation = 'LITTER_BOX_LOCATION';
  static const String leashHarness = 'LEASH_HARNESS';
  static const String petTreats = 'PET_TREATS';
  static const String cleaningSupplies = 'CLEANING_SUPPLIES';
  static const String medicineSupplies = 'MEDICINE_SUPPLIES';

  // 环境交代
  static const String accessCodeLock = 'ACCESS_CODE_LOCK';
  static const String accessKeyCustody = 'ACCESS_KEY_CUSTODY';
  static const String accessProperty = 'ACCESS_PROPERTY';
  static const String accessIntercom = 'ACCESS_INTERCOM';
  static const String accessDoorbell = 'ACCESS_DOORBELL';

  // 视频/拍照打卡
  static const String videoEntryCheckin = 'VIDEO_ENTRY_CHECKIN';
  static const String videoExitCheckin = 'VIDEO_EXIT_CHECKIN';
  static const String photoFeedWater = 'PHOTO_FEED_WATER';
  static const String photoCleanArchive = 'PHOTO_CLEAN_ARCHIVE';

  // 服务选项
  static const String needPlayCompanion = 'NEED_PLAY_COMPANION';
  static const String needCleaning = 'NEED_CLEANING';

  static const List<String> itemGuideTags = <String>[
    foodBowlLocation,
    mainFoodStorage,
    waterBowlLocation,
    litterBoxLocation,
    leashHarness,
    petTreats,
    cleaningSupplies,
    medicineSupplies,
  ];

  static const List<String> environmentTags = <String>[
    accessCodeLock,
    accessKeyCustody,
    accessProperty,
    accessIntercom,
    accessDoorbell,
  ];

  static const List<String> videoCheckinTags = <String>[
    videoEntryCheckin,
    videoExitCheckin,
    photoFeedWater,
    photoCleanArchive,
  ];

  static const List<String> serviceOptionTags = <String>[
    needPlayCompanion,
    needCleaning,
  ];

  static const Map<String, String> labels = <String, String>{
    foodBowlLocation: '食盆位置',
    mainFoodStorage: '主粮存放处',
    waterBowlLocation: '饮水位置',
    litterBoxLocation: '猫砂盆位置',
    leashHarness: '牵引绳/胸背',
    petTreats: '零食/营养品',
    cleaningSupplies: '清洁用品',
    medicineSupplies: '药品/喂药',
    accessCodeLock: '密码锁/门禁码',
    accessKeyCustody: '钥匙托管',
    accessProperty: '物业/前台协助',
    accessIntercom: '对讲开门',
    accessDoorbell: '按门铃联系',
    videoEntryCheckin: '入户视频打卡',
    videoExitCheckin: '离户视频打卡',
    photoFeedWater: '添粮饮水拍照',
    photoCleanArchive: '清理留档拍照',
    needPlayCompanion: '需要陪玩',
    needCleaning: '需要清洁',
  };

  static const Map<String, String> categoryTitles = <String, String>{
    'ITEM_GUIDE': '物品引导',
    'ENVIRONMENT': '环境交代',
    'VIDEO_CHECKIN': '视频/拍照要求',
    'SERVICE_OPTION': '服务选项',
  };

  static String categoryOf(String tagCode) {
    if (itemGuideTags.contains(tagCode)) return 'ITEM_GUIDE';
    if (environmentTags.contains(tagCode)) return 'ENVIRONMENT';
    if (videoCheckinTags.contains(tagCode)) return 'VIDEO_CHECKIN';
    if (serviceOptionTags.contains(tagCode)) return 'SERVICE_OPTION';
    return 'OTHER';
  }

  static List<String> describeTags(List<String> tags) {
    return tags
        .map((code) => labels[code] ?? code)
        .where((label) => label.isNotEmpty)
        .toList();
  }
}
