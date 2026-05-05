import 'package:flutter/material.dart';

enum MePresenceStatus { online, offline }

class MeActionItem {
  const MeActionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String action;
}

class MeVibeItem {
  const MeVibeItem({
    required this.title,
    required this.body,
    required this.timeAgo,
    required this.tag,
    required this.likes,
    required this.comments,
    required this.mediaType,
    required this.mentions,
    required this.usesMentionAll,
    required this.icon,
    required this.colors,
  });

  final String title;
  final String body;
  final String timeAgo;
  final String tag;
  final String likes;
  final String comments;
  final String mediaType;
  final List<String> mentions;
  final bool usesMentionAll;
  final IconData icon;
  final List<Color> colors;
}

const List<MeVibeItem> mockMyVibes = [
  MeVibeItem(
    title: 'Founder room update',
    body: 'Polishing Vibe Match live rooms, profiles and premium modules today.',
    timeAgo: '2h ago',
    tag: 'Room',
    likes: '1.8K',
    comments: '126',
    mediaType: 'Photo',
    mentions: ['@team'],
    usesMentionAll: false,
    icon: Icons.photo_rounded,
    colors: [Color(0xFF12C7B7), Color(0xFF6D5DF6)],
  ),
  MeVibeItem(
    title: 'Family event prep',
    body: 'Moon Fam is getting ready for events, rewards and contribution ranking.',
    timeAgo: '9h ago',
    tag: 'Family',
    likes: '940',
    comments: '58',
    mediaType: 'Video',
    mentions: ['@MoonFam'],
    usesMentionAll: true,
    icon: Icons.play_arrow_rounded,
    colors: [Color(0xFFE84C72), Color(0xFFFFD36A)],
  ),
  MeVibeItem(
    title: 'Premium profile polish',
    body: 'VIP, SVIP, official tags, presence and room status should feel clean.',
    timeAgo: '1d ago',
    tag: 'Profile',
    likes: '722',
    comments: '39',
    mediaType: 'Photo',
    mentions: [],
    usesMentionAll: false,
    icon: Icons.auto_awesome_rounded,
    colors: [Color(0xFF6D5DF6), Color(0xFFE84C72)],
  ),
];

List<MeActionItem> buildMeActionItems({
  required int vipLevel,
  required int svipLevel,
  required String coverPhotoStatus,
}) {
  return [
    MeActionItem(
      icon: Icons.person_rounded,
      title: 'Edit Profile',
      subtitle: 'Avatar, name, bio, presence and profile display',
      color: Color(0xFF12C7B7),
      action: 'Edit Profile page will open.',
    ),
    MeActionItem(
      icon: Icons.image_rounded,
      title: 'Cover Photo',
      subtitle: coverPhotoStatus,
      color: Color(0xFF6D5DF6),
      action: 'Cover photo editor will open.',
    ),
    MeActionItem(
      icon: Icons.workspace_premium_rounded,
      title: 'VIP / SVIP Center',
      subtitle: 'VIP $vipLevel active · SVIP $svipLevel monthly',
      color: Color(0xFFC99A3B),
      action: 'VIP and SVIP center will open.',
    ),
    MeActionItem(
      icon: Icons.favorite_rounded,
      title: 'Love & Bonds',
      subtitle: 'View your linked relationships and badges',
      color: Color(0xFFE84C72),
      action: 'Relationships page will open.',
    ),
    MeActionItem(
      icon: Icons.groups_rounded,
      title: 'Family',
      subtitle: 'Join a family, view members, and play family events',
      color: Color(0xFF12C7B7),
      action: 'Family page with events, members and rewards will open.',
    ),
    MeActionItem(
      icon: Icons.storefront_rounded,
      title: 'Store & Inventory',
      subtitle: 'Themes, entrance effects, equipped items',
      color: Color(0xFF6D5DF6),
      action: 'Store and Inventory page will open.',
    ),
    MeActionItem(
      icon: Icons.admin_panel_settings_rounded,
      title: 'Control Center',
      subtitle: 'Shown only for allowed roles',
      color: Color(0xFFE84C72),
      action: 'Role-based Control Center will open if permitted.',
    ),
    MeActionItem(
      icon: Icons.refresh_rounded,
      title: 'Refresh Profile',
      subtitle: 'Reload current user from backend',
      color: Color(0xFF12C7B7),
      action: 'refresh',
    ),
    MeActionItem(
      icon: Icons.settings_rounded,
      title: 'Settings',
      subtitle: 'Privacy, account, notifications, security',
      color: Color(0xFF251538),
      action: 'Settings page will open.',
    ),
    MeActionItem(
      icon: Icons.help_center_rounded,
      title: 'Help Centre',
      subtitle: 'Support, FAQs, safety, reports and contact options',
      color: Color(0xFF12C7B7),
      action: 'Help Centre will open.',
    ),
    MeActionItem(
      icon: Icons.logout_rounded,
      title: 'Logout',
      subtitle: 'Return to login screen',
      color: Color(0xFFE84C72),
      action: 'logout',
    ),
  ];
}
