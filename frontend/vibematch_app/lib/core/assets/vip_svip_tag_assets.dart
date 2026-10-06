import 'funkey_cdn_assets.dart';

class VipSvipTagAssets {
  const VipSvipTagAssets._();

  static String vipTagForLevel(int level) => FunKeyCdnAssets.vipTag(level);

  static String svipTagForLevel(int level) => FunKeyCdnAssets.svipTag(level);

  static List<String> get vipTagPaths =>
      List<String>.generate(50, (index) => vipTagForLevel(index + 1));

  static List<String> get svipTagPaths =>
      List<String>.generate(10, (index) => svipTagForLevel(index + 1));
}
