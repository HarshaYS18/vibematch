import 'package:flutter/material.dart';

/// Central icon registry for VibeMatch.
///
/// Feature screens should use this file instead of importing random icon packs
/// directly. Keeping navigation icons on Flutter's built-in Material set avoids
/// coupling application startup to a third-party icon font package.
abstract final class VMIcons {
  // Main navigation.
  static const IconData home = Icons.home_rounded;
  static const IconData vibes = Icons.auto_awesome_rounded;
  static const IconData create = Icons.add_circle_rounded;
  static const IconData inbox = Icons.chat_bubble_rounded;
  static const IconData profile = Icons.person_rounded;

  // Global actions.
  static const IconData search = Icons.search_rounded;
  static const IconData notifications = Icons.notifications_rounded;
  static const IconData settings = Icons.settings_rounded;
  static const IconData more = Icons.more_vert_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData back = Icons.arrow_back_rounded;
  static const IconData chevronRight = Icons.chevron_right_rounded;
  static const IconData check = Icons.check_rounded;
  static const IconData checkCircle = Icons.check_circle_rounded;
  static const IconData refresh = Icons.refresh_rounded;
  static const IconData edit = Icons.edit_rounded;
  static const IconData share = Icons.share_rounded;
  static const IconData logout = Icons.logout_rounded;
  static const IconData helpCenter = Icons.help_center_rounded;

  // App/admin/status.
  static const IconData admin = Icons.admin_panel_settings_rounded;
  static const IconData verified = Icons.verified_rounded;
  static const IconData verifiedUser = Icons.verified_user_rounded;
  static const IconData active = Icons.radio_button_checked_rounded;
  static const IconData inactive = Icons.radio_button_unchecked_rounded;
  static const IconData cloudDone = Icons.cloud_done_rounded;
  static const IconData wifiOff = Icons.wifi_off_rounded;

  // Home/discovery.
  static const IconData createRoom = Icons.add_home_work_rounded;
  static const IconData publicRoom = Icons.public_rounded;
  static const IconData people = Icons.people_rounded;
  static const IconData fire = Icons.local_fire_department_rounded;
  static const IconData category = Icons.category_rounded;
  static const IconData music = Icons.music_note_rounded;
  static const IconData bolt = Icons.bolt_rounded;
  static const IconData audioWave = Icons.graphic_eq_rounded;

  // Media / content.
  static const IconData photo = Icons.photo_rounded;
  static const IconData play = Icons.play_arrow_rounded;
  static const IconData sparkle = Icons.auto_awesome_rounded;
  static const IconData coverPhoto = Icons.image_rounded;

  // Social / profile.
  static const IconData user = Icons.person_rounded;
  static const IconData userAdd = Icons.person_add_alt_1_rounded;
  static const IconData users = Icons.groups_rounded;
  static const IconData friends = Icons.handshake_rounded;
  static const IconData family = Icons.diversity_1_rounded;
  static const IconData official = Icons.verified_rounded;
  static const IconData heart = Icons.favorite_rounded;
  static const IconData comment = Icons.mode_comment_rounded;
  static const IconData mention = Icons.alternate_email_rounded;

  // Room / live audio.
  static const IconData room = Icons.forum_rounded;
  static const IconData mic = Icons.mic_rounded;
  static const IconData micMuted = Icons.mic_off_rounded;
  static const IconData seat = Icons.event_seat_rounded;
  static const IconData lock = Icons.lock_rounded;
  static const IconData unlock = Icons.lock_open_rounded;
  static const IconData invite = Icons.person_add_alt_1_rounded;
  static const IconData leaveSeat = Icons.keyboard_arrow_down_rounded;
  static const IconData kick = Icons.person_remove_alt_1_rounded;
  static const IconData image = Icons.image_rounded;
  static const IconData emoji = Icons.emoji_emotions_rounded;
  static const IconData send = Icons.send_rounded;
  static const IconData language = Icons.language_rounded;
  static const IconData secret = Icons.visibility_off_rounded;
  static const IconData applyOnly = Icons.rule_rounded;
  static const IconData roomBackground = Icons.wallpaper_rounded;

  // Monetization / store.
  static const IconData gift = Icons.card_giftcard_rounded;
  static const IconData wallet = Icons.account_balance_wallet_rounded;
  static const IconData coin = Icons.monetization_on_rounded;
  static const IconData diamond = Icons.diamond_rounded;
  static const IconData store = Icons.storefront_rounded;
  static const IconData baggage = Icons.inventory_2_rounded;
  static const IconData crown = Icons.workspace_premium_rounded;
  static const IconData vip = Icons.military_tech_rounded;
  static const IconData svip = Icons.star_rounded;

  // Rankings / events / games.
  static const IconData trophy = Icons.emoji_events_rounded;
  static const IconData ranking = Icons.leaderboard_rounded;
  static const IconData event = Icons.event_rounded;
  static const IconData broadcast = Icons.campaign_rounded;
  static const IconData games = Icons.sports_esports_rounded;
  static const IconData watchParty = Icons.smart_display_rounded;
  static const IconData cricket = Icons.sports_cricket_rounded;

  // Moderation / safety.
  static const IconData shield = Icons.shield_rounded;
  static const IconData report = Icons.report_gmailerrorred_rounded;
  static const IconData block = Icons.block_rounded;
  static const IconData ban = Icons.gavel_rounded;
  static const IconData audit = Icons.receipt_long_rounded;
}
