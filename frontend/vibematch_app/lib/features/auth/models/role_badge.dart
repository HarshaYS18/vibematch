import 'package:flutter/material.dart';

class RoleBadge {
  const RoleBadge({
    required this.role,
    required this.displayTitle,
    required this.badgeLabel,
    required this.pillLabel,
    required this.group,
    required this.priority,
    required this.icon,
    required this.backgroundColor,
    required this.textColor,
    required this.borderColor,
    required this.showVerifiedTick,
  });

  final String role;
  final String displayTitle;
  final String badgeLabel;
  final String pillLabel;
  final String group;
  final int priority;
  final String icon;
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;
  final bool showVerifiedTick;

  factory RoleBadge.fromJson(Map<String, dynamic> json) {
    return RoleBadge(
      role: _stringFromJson(json, ['role'], fallback: 'user'),
      displayTitle: _stringFromJson(json, ['display_title', 'displayTitle'], fallback: 'User'),
      badgeLabel: _stringFromJson(json, ['badge_label', 'badgeLabel'], fallback: 'User'),
      pillLabel: _stringFromJson(json, ['pill_label', 'pillLabel'], fallback: 'User'),
      group: _stringFromJson(json, ['group'], fallback: 'user'),
      priority: _intFromJson(json, ['priority'], fallback: 0),
      icon: _stringFromJson(json, ['icon'], fallback: 'verified'),
      backgroundColor: _colorFromJson(json, ['background_color', 'backgroundColor'], fallback: const Color(0xFF251538)),
      textColor: _colorFromJson(json, ['text_color', 'textColor'], fallback: const Color(0xFFFFD36A)),
      borderColor: _colorFromJson(json, ['border_color', 'borderColor'], fallback: const Color(0xFFC99A3B)),
      showVerifiedTick: _boolFromJson(json, ['show_verified_tick', 'showVerifiedTick'], fallback: false),
    );
  }

  factory RoleBadge.fromRole(String role) {
    switch (role.trim().toLowerCase()) {
      case 'founder_owner':
      case 'super_owner':
        return const RoleBadge(
          role: 'founder_owner',
          displayTitle: 'Super Owner',
          badgeLabel: 'Head Official',
          pillLabel: 'Super Owner · Head Official',
          group: 'official',
          priority: 100,
          icon: 'workspace_premium',
          backgroundColor: Color(0xFF2A1600),
          textColor: Color(0xFFFFD36A),
          borderColor: Color(0xFFF4B63D),
          showVerifiedTick: true,
        );
      case 'owner':
        return const RoleBadge(
          role: 'owner',
          displayTitle: 'Owner',
          badgeLabel: 'Official',
          pillLabel: 'Owner · Official',
          group: 'official',
          priority: 90,
          icon: 'verified',
          backgroundColor: Color(0xFF24133A),
          textColor: Color(0xFFFFD36A),
          borderColor: Color(0xFFC99A3B),
          showVerifiedTick: true,
        );
      case 'superadmin':
        return const RoleBadge(
          role: 'superadmin',
          displayTitle: 'Super Admin',
          badgeLabel: 'Admin Official Lv1',
          pillLabel: 'Super Admin · Admin Official Lv1',
          group: 'admin_official',
          priority: 80,
          icon: 'admin_panel_settings',
          backgroundColor: Color(0xFF1C233A),
          textColor: Color(0xFF9AD7FF),
          borderColor: Color(0xFF4A9BFF),
          showVerifiedTick: false,
        );
      case 'admin':
        return const RoleBadge(
          role: 'admin',
          displayTitle: 'Admin',
          badgeLabel: 'Admin Official Lv2',
          pillLabel: 'Admin · Admin Official Lv2',
          group: 'admin_official',
          priority: 70,
          icon: 'shield',
          backgroundColor: Color(0xFF1B2630),
          textColor: Color(0xFFAEE9D8),
          borderColor: Color(0xFF12C7B7),
          showVerifiedTick: false,
        );
      case 'coin_seller':
        return const RoleBadge(
          role: 'coin_seller',
          displayTitle: 'Coin Seller',
          badgeLabel: 'Coin Seller',
          pillLabel: 'Coin Seller',
          group: 'business',
          priority: 45,
          icon: 'paid',
          backgroundColor: Color(0xFF2A1E0D),
          textColor: Color(0xFFFFD36A),
          borderColor: Color(0xFFC99A3B),
          showVerifiedTick: false,
        );
      case 'merchant':
      case 'reseller':
        return const RoleBadge(
          role: 'merchant',
          displayTitle: 'Merchant',
          badgeLabel: 'Merchant',
          pillLabel: 'Merchant',
          group: 'business',
          priority: 44,
          icon: 'storefront',
          backgroundColor: Color(0xFF231A30),
          textColor: Color(0xFFD7B8FF),
          borderColor: Color(0xFF8C5CF6),
          showVerifiedTick: false,
        );
      case 'agency_owner':
      case 'bd':
        return const RoleBadge(
          role: 'agency_owner',
          displayTitle: 'Agency Owner',
          badgeLabel: 'Agency Official',
          pillLabel: 'Agency Owner · Agency Official',
          group: 'agency',
          priority: 50,
          icon: 'groups',
          backgroundColor: Color(0xFF112B25),
          textColor: Color(0xFF9EF2D3),
          borderColor: Color(0xFF12C7B7),
          showVerifiedTick: false,
        );
      case 'agency_member':
      case 'host':
        return const RoleBadge(
          role: 'agency_member',
          displayTitle: 'Agency Member',
          badgeLabel: 'Host',
          pillLabel: 'Agency Member · Host',
          group: 'agency',
          priority: 30,
          icon: 'mic_external_on',
          backgroundColor: Color(0xFF191B2F),
          textColor: Color(0xFFAAB6FF),
          borderColor: Color(0xFF6D5DF6),
          showVerifiedTick: false,
        );
      default:
        return const RoleBadge(
          role: 'user',
          displayTitle: 'User',
          badgeLabel: 'Member',
          pillLabel: 'Member',
          group: 'user',
          priority: 0,
          icon: 'person',
          backgroundColor: Color(0xFFF7F1EA),
          textColor: Color(0xFF6E6078),
          borderColor: Color(0xFFE6D9CE),
          showVerifiedTick: false,
        );
    }
  }

  IconData get iconData {
    switch (icon) {
      case 'workspace_premium':
        return Icons.workspace_premium_rounded;
      case 'verified':
        return Icons.verified_rounded;
      case 'admin_panel_settings':
        return Icons.admin_panel_settings_rounded;
      case 'shield':
        return Icons.shield_rounded;
      case 'paid':
        return Icons.paid_rounded;
      case 'storefront':
        return Icons.storefront_rounded;
      case 'groups':
        return Icons.groups_rounded;
      case 'mic_external_on':
        return Icons.mic_external_on_rounded;
      case 'support_agent':
        return Icons.support_agent_rounded;
      case 'health_and_safety':
        return Icons.health_and_safety_rounded;
      default:
        return Icons.verified_user_rounded;
    }
  }

  static String _stringFromJson(Map<String, dynamic> json, List<String> keys, {required String fallback}) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  static int _intFromJson(Map<String, dynamic> json, List<String> keys, {required int fallback}) {
    for (final key in keys) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return fallback;
  }

  static bool _boolFromJson(Map<String, dynamic> json, List<String> keys, {required bool fallback}) {
    for (final key in keys) {
      final value = json[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1' || normalized == 'yes') return true;
        if (normalized == 'false' || normalized == '0' || normalized == 'no') return false;
      }
    }
    return fallback;
  }

  static Color _colorFromJson(Map<String, dynamic> json, List<String> keys, {required Color fallback}) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isEmpty) continue;
      final normalized = text.replaceFirst('#', '');
      final parsed = int.tryParse('FF$normalized', radix: 16);
      if (parsed != null) return Color(parsed);
    }
    return fallback;
  }
}
