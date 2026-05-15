class VipSvipTagAssets {
  const VipSvipTagAssets._();

  static const String vipBasePath = 'assets/images/vip_tags';
  static const String svipBasePath = 'assets/images/svip_tags';

  static String vipTagForLevel(int level) {
    final safeLevel = level.clamp(1, 50).toString().padLeft(2, '0');
    return '$vipBasePath/vip_tag_lv_$safeLevel.png';
  }

  static String svipTagForLevel(int level) {
    final safeLevel = level.clamp(1, 10).toString().padLeft(2, '0');
    return '$svipBasePath/svip_tag_lv_$safeLevel.png';
  }

  static const List<String> vipTagPaths = [
    'assets/images/vip_tags/vip_tag_lv_01.png',
    'assets/images/vip_tags/vip_tag_lv_02.png',
    'assets/images/vip_tags/vip_tag_lv_03.png',
    'assets/images/vip_tags/vip_tag_lv_04.png',
    'assets/images/vip_tags/vip_tag_lv_05.png',
    'assets/images/vip_tags/vip_tag_lv_06.png',
    'assets/images/vip_tags/vip_tag_lv_07.png',
    'assets/images/vip_tags/vip_tag_lv_08.png',
    'assets/images/vip_tags/vip_tag_lv_09.png',
    'assets/images/vip_tags/vip_tag_lv_10.png',
    'assets/images/vip_tags/vip_tag_lv_11.png',
    'assets/images/vip_tags/vip_tag_lv_12.png',
    'assets/images/vip_tags/vip_tag_lv_13.png',
    'assets/images/vip_tags/vip_tag_lv_14.png',
    'assets/images/vip_tags/vip_tag_lv_15.png',
    'assets/images/vip_tags/vip_tag_lv_16.png',
    'assets/images/vip_tags/vip_tag_lv_17.png',
    'assets/images/vip_tags/vip_tag_lv_18.png',
    'assets/images/vip_tags/vip_tag_lv_19.png',
    'assets/images/vip_tags/vip_tag_lv_20.png',
    'assets/images/vip_tags/vip_tag_lv_21.png',
    'assets/images/vip_tags/vip_tag_lv_22.png',
    'assets/images/vip_tags/vip_tag_lv_23.png',
    'assets/images/vip_tags/vip_tag_lv_24.png',
    'assets/images/vip_tags/vip_tag_lv_25.png',
    'assets/images/vip_tags/vip_tag_lv_26.png',
    'assets/images/vip_tags/vip_tag_lv_27.png',
    'assets/images/vip_tags/vip_tag_lv_28.png',
    'assets/images/vip_tags/vip_tag_lv_29.png',
    'assets/images/vip_tags/vip_tag_lv_30.png',
    'assets/images/vip_tags/vip_tag_lv_31.png',
    'assets/images/vip_tags/vip_tag_lv_32.png',
    'assets/images/vip_tags/vip_tag_lv_33.png',
    'assets/images/vip_tags/vip_tag_lv_34.png',
    'assets/images/vip_tags/vip_tag_lv_35.png',
    'assets/images/vip_tags/vip_tag_lv_36.png',
    'assets/images/vip_tags/vip_tag_lv_37.png',
    'assets/images/vip_tags/vip_tag_lv_38.png',
    'assets/images/vip_tags/vip_tag_lv_39.png',
    'assets/images/vip_tags/vip_tag_lv_40.png',
    'assets/images/vip_tags/vip_tag_lv_41.png',
    'assets/images/vip_tags/vip_tag_lv_42.png',
    'assets/images/vip_tags/vip_tag_lv_43.png',
    'assets/images/vip_tags/vip_tag_lv_44.png',
    'assets/images/vip_tags/vip_tag_lv_45.png',
    'assets/images/vip_tags/vip_tag_lv_46.png',
    'assets/images/vip_tags/vip_tag_lv_47.png',
    'assets/images/vip_tags/vip_tag_lv_48.png',
    'assets/images/vip_tags/vip_tag_lv_49.png',
    'assets/images/vip_tags/vip_tag_lv_50.png',
  ];

  static const List<String> svipTagPaths = [
    'assets/images/svip_tags/svip_tag_lv_01.png',
    'assets/images/svip_tags/svip_tag_lv_02.png',
    'assets/images/svip_tags/svip_tag_lv_03.png',
    'assets/images/svip_tags/svip_tag_lv_04.png',
    'assets/images/svip_tags/svip_tag_lv_05.png',
    'assets/images/svip_tags/svip_tag_lv_06.png',
    'assets/images/svip_tags/svip_tag_lv_07.png',
    'assets/images/svip_tags/svip_tag_lv_08.png',
    'assets/images/svip_tags/svip_tag_lv_09.png',
    'assets/images/svip_tags/svip_tag_lv_10.png',
  ];
}
