import 'package:flutter/material.dart';

import '../../../auth/models/current_user.dart';
import '../models/me_page_models.dart';

class MeProfileConstants {
  const MeProfileConstants._();

  static const int vipLevel = 25;
  static const int svipLevel = 3;
  static const bool vipFrozen = false;
  static const int diamonds = 128500;
  static const int coins = 3420000;
  static const String coverPhotoStatus = 'Premium cover photo ready';
  static const MePresenceStatus presence = MePresenceStatus.online;
  static const String lastSeenText = 'online';
  static const String? currentRoomName = 'Founder Lounge';
  static const String familyName = 'Moon Fam';
  static const int familyLevel = 12;

  static String displayNameFor(CurrentUser user) {
    return user.displayName ?? user.username ?? 'Vibe User';
  }

  static String relationshipTypeFor(CurrentUser user) {
    final name = (user.displayName ?? user.username ?? '').toLowerCase();
    if (name.contains('riya') || name.contains('meera') || name.contains('aadhya')) {
      return 'Sister';
    }
    return 'Brother';
  }

  static String? roleTagFor(String role) {
    final normalized = role.toLowerCase().trim();
    if (normalized == 'founder_owner') return 'Founder Owner';
    if (normalized == 'super_owner') return 'Super Owner';
    if (normalized == 'owner') return 'Owner';
    if (normalized == 'superadmin') return 'SuperAdmin';
    if (normalized == 'admin') return 'Admin';
    if (normalized == 'monitor') return 'Monitor';
    if (normalized == 'cs') return 'CS';
    return null;
  }

  static Color vipMainColor(int level) {
    if (level >= 41) return const Color(0xFFE6B84D);
    if (level >= 31) return const Color(0xFF3FB6FF);
    if (level >= 21) return const Color(0xFFE84C72);
    if (level >= 11) return const Color(0xFF8C5CF6);
    return const Color(0xFF12C7B7);
  }

  static Color vipDarkColor(int level) {
    if (level >= 41) return const Color(0xFF1D1510);
    if (level >= 31) return const Color(0xFF103A66);
    if (level >= 21) return const Color(0xFF5C102B);
    if (level >= 11) return const Color(0xFF351A67);
    return const Color(0xFF064D46);
  }

  static String formatNumber(int value) {
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
