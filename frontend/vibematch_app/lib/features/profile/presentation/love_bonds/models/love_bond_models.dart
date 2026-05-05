import 'package:flutter/material.dart';

enum LoveBondType { lover, bestie, brother, sister }

class LoveBondCardData {
  const LoveBondCardData({
    required this.type,
    required this.title,
    required this.level,
    required this.displayName,
    required this.primaryColor,
    required this.secondaryColor,
    required this.icon,
    required this.badgeIcon,
    required this.leftAvatarInitial,
    required this.rightAvatarInitial,
  });

  final LoveBondType type;
  final String title;
  final int level;
  final String displayName;
  final Color primaryColor;
  final Color secondaryColor;
  final IconData icon;
  final IconData badgeIcon;
  final String leftAvatarInitial;
  final String rightAvatarInitial;
}

class LoveBondTaskData {
  const LoveBondTaskData({
    required this.title,
    required this.subtitle,
    required this.progressLabel,
    required this.progress,
    required this.reward,
    required this.icon,
    required this.capped,
  });

  final String title;
  final String subtitle;
  final String progressLabel;
  final double progress;
  final int reward;
  final IconData icon;
  final bool capped;
}

const List<LoveBondCardData> mockLoveBondCards = [
  LoveBondCardData(
    type: LoveBondType.lover,
    title: 'Lover',
    level: 3,
    displayName: 'REPSARAH → ♡',
    primaryColor: Color(0xFFFF5AAA),
    secondaryColor: Color(0xFFFFC2DC),
    icon: Icons.home_rounded,
    badgeIcon: Icons.favorite_rounded,
    leftAvatarInitial: 'S',
    rightAvatarInitial: 'R',
  ),
  LoveBondCardData(
    type: LoveBondType.bestie,
    title: 'Bestie',
    level: 2,
    displayName: 'RIDE OR DIE → ☆',
    primaryColor: Color(0xFF9C5CFF),
    secondaryColor: Color(0xFFE2CCFF),
    icon: Icons.night_shelter_rounded,
    badgeIcon: Icons.favorite_rounded,
    leftAvatarInitial: 'A',
    rightAvatarInitial: 'M',
  ),
  LoveBondCardData(
    type: LoveBondType.brother,
    title: 'Brother',
    level: 1,
    displayName: 'BRO CODE → ⚡',
    primaryColor: Color(0xFF4C8DFF),
    secondaryColor: Color(0xFFCFE2FF),
    icon: Icons.sports_esports_rounded,
    badgeIcon: Icons.bolt_rounded,
    leftAvatarInitial: 'K',
    rightAvatarInitial: 'V',
  ),
  LoveBondCardData(
    type: LoveBondType.sister,
    title: 'Sister',
    level: 1,
    displayName: 'SOUL SISTERS → ✿',
    primaryColor: Color(0xFFFFA93D),
    secondaryColor: Color(0xFFFFE0A8),
    icon: Icons.diamond_rounded,
    badgeIcon: Icons.local_florist_rounded,
    leftAvatarInitial: 'N',
    rightAvatarInitial: 'P',
  ),
];

const List<LoveBondTaskData> mockLoverTasks = [
  LoveBondTaskData(
    title: 'Spend time together',
    subtitle: 'Daily cap: 60 min / +300 max affection',
    progressLabel: '45 / 60 min',
    progress: 0.75,
    reward: 300,
    icon: Icons.access_time_filled_rounded,
    capped: true,
  ),
  LoveBondTaskData(
    title: 'Exchange relationship gifts',
    subtitle: 'Send or receive relationship gifts',
    progressLabel: '1 / 3',
    progress: 0.34,
    reward: 450,
    icon: Icons.card_giftcard_rounded,
    capped: false,
  ),
  LoveBondTaskData(
    title: 'Send sweet messages',
    subtitle: 'Send 10 messages',
    progressLabel: '6 / 10',
    progress: 0.60,
    reward: 200,
    icon: Icons.mark_email_unread_rounded,
    capped: false,
  ),
  LoveBondTaskData(
    title: 'Join a room together',
    subtitle: 'Stay in the same room for 20 min',
    progressLabel: '10 / 20 min',
    progress: 0.50,
    reward: 250,
    icon: Icons.cottage_rounded,
    capped: true,
  ),
];
