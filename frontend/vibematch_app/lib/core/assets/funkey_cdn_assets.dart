import '../network/vm_api_config.dart';

/// Canonical URL builder for FunKey-owned CDN presentation media.
///
/// The Flutter bundle intentionally contains only the FunKey launcher/logo
/// asset. All other product media must resolve through the public CDN origin.
abstract final class FunKeyCdnAssets {
  static String url(String objectKey) {
    final clean = objectKey.trim().replaceFirst(RegExp(r'^/+'), '');
    if (clean.isEmpty) return '';
    return '${VmApiConfig.cdnOrigin}/$clean';
  }

  static String vipTag(int level) {
    final safeLevel = level.clamp(1, 50).toString().padLeft(2, '0');
    return url('ui/vip/tags/v1/vip_tag_lv_$safeLevel.png');
  }

  static String svipTag(int level) {
    final safeLevel = level.clamp(1, 10).toString().padLeft(2, '0');
    return url('ui/svip/tags/v1/svip_tag_lv_$safeLevel.png');
  }

  static String familyBadge(String level) {
    final normalized = switch (level.trim().toLowerCase()) {
      'platinum' => 'platinum',
      'gold' => 'gold',
      'silver' => 'silver',
      _ => 'bronze',
    };
    return url('ui/family/badges/v1/$normalized.png');
  }

  static String cricketBackground(String name) =>
      url('ui/rooms/cricket/backgrounds/v1/$name.webp');

  static String get miniProfilePurpleGoldBanner =>
      url('ui/profile/decorations/v1/purple_gold_banner.png');

  static String get premiumGiftBroadcastFrame =>
      url('ui/gifts/broadcast/v1/premium_gift_broadcast_frame.png');

  static String get legacyVibeMatchLogo =>
      url('ui/branding/v1/vibe_match_logo.png');

  static String giftVideo(String giftId) =>
      url('gifts/$giftId/v1/animation.mp4');
}
