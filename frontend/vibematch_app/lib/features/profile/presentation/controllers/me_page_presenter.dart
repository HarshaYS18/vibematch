import 'package:flutter/material.dart';

import '../../auth/models/current_user.dart';
import '../models/me_page_models.dart';

class MePagePresenter {
  const MePagePresenter(this.user);

  final CurrentUser user;

  static const int vipLevel = 25;
  static const int svipLevel = 3;
  static const bool vipFrozen = false;
  static const int diamonds = 128500;
  static const int coins = 3420000;
  static const bool isAgencyHost = false;
  static const String coverPhotoStatus = 'Premium cover photo ready';
  static const MePresenceStatus presence = MePresenceStatus.online;
  static const String lastSeenText = 'online';
  static const String? currentRoomName = 'Founder Lounge';
  static const String familyName = 'Moon Fam';
  static const int familyLevel = 12;

  String get displayName => user.displayName ?? user.username ?? 'Vibe User';
  String get publicId => user.publicUserId.toString();
  String get role => user.primaryRole;

  String get relationshipType {
    final name = (user.displayName ?? user.username ?? '').toLowerCase();
    if (name.contains('riya') || name.contains('meera') || name.contains('aadhya')) {
      return 'Sister';
    }
    return 'Brother';
  }

  String? get roleTag {
    final normalizedRole = role.toLowerCase().trim();
    if (normalizedRole == 'founder_owner') return 'Founder Owner';
    if (normalizedRole == 'super_owner') return 'Super Owner';
    if (normalizedRole == 'owner') return 'Owner';
    if (normalizedRole == 'superadmin') return 'SuperAdmin';
    if (normalizedRole == 'admin') return 'Admin';
    if (normalizedRole == 'monitor') return 'Monitor';
    if (normalizedRole == 'cs') return 'CS';
    if (isAgencyHost) return 'Host';
    return null;
  }

  Color get vipColor => vipMainColor(vipLevel);
  Color get vipDark => vipDarkColor(vipLevel);

  List<MeActionItem> get actionItems => buildMeActionItems(
        vipLevel: vipLevel,
        svipLevel: svipLevel,
        coverPhotoStatus: coverPhotoStatus,
      );

  Color vipMainColor(int level) {
    if (level >= 41) return const Color(0xFFE6B84D);
    if (level >= 31) return const Color(0xFF3FB6FF);
    if (level >= 21) return const Color(0xFFE84C72);
    if (level >= 11) return const Color(0xFF8C5CF6);
    return const Color(0xFF12C7B7);
  }

  Color vipDarkColor(int level) {
    if (level >= 41) return const Color(0xFF1D1510);
    if (level >= 31) return const Color(0xFF103A66);
    if (level >= 21) return const Color(0xFF5C102B);
    if (level >= 11) return const Color(0xFF351A67);
    return const Color(0xFF064D46);
  }

  String formatNumber(int value) {
    if (value >= 1000000) {
      final result = value / 1000000;
      return '${result.toStringAsFixed(result >= 10 ? 0 : 1)}M';
    }
    if (value >= 1000) {
      final result = value / 1000;
      return '${result.toStringAsFixed(result >= 10 ? 0 : 1)}K';
    }
    return value.toString();
  }
}
