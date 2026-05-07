import 'package:flutter/material.dart';

class HelpFaqItem {
  const HelpFaqItem({
    required this.category,
    required this.question,
    required this.answer,
    required this.icon,
  });

  final String category;
  final String question;
  final String answer;
  final IconData icon;
}

class HelpQuickAction {
  const HelpQuickAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.category,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String category;
  final Color color;
}

const List<String> helpCenterCategories = [
  'All',
  'Account',
  'Rooms',
  'Inbox',
  'Safety',
  'Payments',
  'VIP',
  'Agency',
];

const List<HelpQuickAction> helpQuickActions = [
  HelpQuickAction(
    title: 'Report a user or room',
    subtitle: 'Safety, abuse, vulgar DP, harassment or scam.',
    icon: Icons.report_rounded,
    category: 'Safety',
    color: Color(0xFFE84C72),
  ),
  HelpQuickAction(
    title: 'Payment or recharge issue',
    subtitle: 'Rubies, coins, VIP/SVIP, gifts or failed recharge.',
    icon: Icons.payments_rounded,
    category: 'Payments',
    color: Color(0xFFC99A3B),
  ),
  HelpQuickAction(
    title: 'Room access problem',
    subtitle: 'Locked room, Secret Vibe, seat, mute or kick issue.',
    icon: Icons.graphic_eq_rounded,
    category: 'Rooms',
    color: Color(0xFF6D5DF6),
  ),
  HelpQuickAction(
    title: 'Inbox or privacy help',
    subtitle: 'Stranger messages, invites, notifications and Inbox lock.',
    icon: Icons.inbox_rounded,
    category: 'Inbox',
    color: Color(0xFF12C7B7),
  ),
];

const List<HelpFaqItem> helpFaqItems = [
  HelpFaqItem(
    category: 'Account',
    question: 'How do I edit my profile?',
    answer: 'Open Me, tap Edit Profile, update your avatar, name, bio, date of birth, gender, interests and friend preferences, then save.',
    icon: Icons.person_rounded,
  ),
  HelpFaqItem(
    category: 'Account',
    question: 'How does profile QR work?',
    answer: 'Open the QR button on your Me card. Scan QR opens camera/gallery scan. My QR creates a Vibe Match profile QR that opens your public profile.',
    icon: Icons.qr_code_2_rounded,
  ),
  HelpFaqItem(
    category: 'Rooms',
    question: 'Why can I not enter a locked room?',
    answer: 'Locked rooms require a password or a valid owner/admin invite. Secret Vibe rooms require invite permission and may be hidden from discovery.',
    icon: Icons.lock_rounded,
  ),
  HelpFaqItem(
    category: 'Rooms',
    question: 'Why can I not unmute myself?',
    answer: 'If you muted yourself, you can unmute. If a host/admin muted you, only the room owner or authorized admin can unmute you.',
    icon: Icons.mic_off_rounded,
  ),
  HelpFaqItem(
    category: 'Rooms',
    question: 'How do seats work?',
    answer: 'Normal users can take empty unlocked seats. Owner/admins can invite, switch, lock or unlock seats based on room permissions.',
    icon: Icons.event_seat_rounded,
  ),
  HelpFaqItem(
    category: 'Inbox',
    question: 'Where are room invites shown?',
    answer: 'Room invites appear in Inbox and as floating realtime notifications when enabled in Settings.',
    icon: Icons.mark_email_unread_rounded,
  ),
  HelpFaqItem(
    category: 'Inbox',
    question: 'What are Stranger Messages?',
    answer: 'Messages from users who are not mutual friends are grouped under Stranger Messages. You can control this from Settings.',
    icon: Icons.forum_rounded,
  ),
  HelpFaqItem(
    category: 'Safety',
    question: 'How do I report abuse?',
    answer: 'Use Help Centre quick actions or report controls in the related room/profile. Reports should include reason and details for moderator review.',
    icon: Icons.security_rounded,
  ),
  HelpFaqItem(
    category: 'Safety',
    question: 'What happens with vulgar profile pictures?',
    answer: 'Vulgar or unsafe DPs can be reported and later should be reviewed by AI plus monitor team rules before action is taken.',
    icon: Icons.shield_rounded,
  ),
  HelpFaqItem(
    category: 'Payments',
    question: 'What are Rubies and Coins?',
    answer: 'Rubies/diamonds are recharge value used for app economy. Coins are used for app interactions such as gifts depending on backend rules.',
    icon: Icons.diamond_rounded,
  ),
  HelpFaqItem(
    category: 'Payments',
    question: 'A recharge or gift failed. What should I do?',
    answer: 'Create a support ticket with date, amount, payment status, user ID and screenshot details. Support can verify against backend records later.',
    icon: Icons.receipt_long_rounded,
  ),
  HelpFaqItem(
    category: 'VIP',
    question: 'What is the difference between VIP and SVIP?',
    answer: 'VIP is long-term recharge-based level. SVIP is monthly/seasonal status unlocked by monthly recharge thresholds and can expire/reset monthly.',
    icon: Icons.workspace_premium_rounded,
  ),
  HelpFaqItem(
    category: 'VIP',
    question: 'What is anonymous chatroom appearance?',
    answer: 'Anonymous chatroom appearance is an SVIP setting that hides your public identity in supported chatroom contexts according to backend privacy rules.',
    icon: Icons.masks_rounded,
  ),
  HelpFaqItem(
    category: 'Agency',
    question: 'Can I join multiple agencies?',
    answer: 'No. Agency owners, agency admins and hosts can belong to only one active agency at a time according to Vibe Match agency rules.',
    icon: Icons.groups_rounded,
  ),
  HelpFaqItem(
    category: 'Agency',
    question: 'Who can remove a host from an agency?',
    answer: 'Agency owners can remove hosts. Agency admins can invite/accept hosts but cannot remove hosts or manage admins.',
    icon: Icons.admin_panel_settings_rounded,
  ),
];
