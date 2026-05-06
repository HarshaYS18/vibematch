import 'package:flutter/material.dart';

enum FamilyRole {
  owner('Owner'),
  admin('Admin'),
  member('Member');

  const FamilyRole(this.label);
  final String label;
}

enum FamilyChannelTab {
  vibes('Vibes'),
  chat('Chat');

  const FamilyChannelTab(this.label);
  final String label;
}

class FamilyMemberUiModel {
  const FamilyMemberUiModel({
    required this.userId,
    required this.name,
    required this.role,
    required this.contributionExp,
    required this.avatarGradient,
    required this.isFollowing,
  });

  final String userId;
  final String name;
  final FamilyRole role;
  final int contributionExp;
  final List<Color> avatarGradient;
  final bool isFollowing;

  String get avatarText => name.trim().isEmpty ? 'F' : name.trim()[0].toUpperCase();
}

class FamilyVibeUiModel {
  const FamilyVibeUiModel({
    required this.id,
    required this.authorName,
    required this.caption,
    required this.tag,
    required this.isVideo,
    required this.likes,
    required this.comments,
    required this.gradient,
  });

  final String id;
  final String authorName;
  final String caption;
  final String tag;
  final bool isVideo;
  final int likes;
  final int comments;
  final List<Color> gradient;

  String get avatarText => authorName.trim().isEmpty ? 'F' : authorName.trim()[0].toUpperCase();
}

class FamilyChatUiModel {
  const FamilyChatUiModel({
    required this.senderName,
    required this.message,
    required this.timeLabel,
    required this.isMine,
  });

  final String senderName;
  final String message;
  final String timeLabel;
  final bool isMine;
}

class FamilyProfileUiModel {
  const FamilyProfileUiModel({
    required this.id,
    required this.name,
    required this.minimumVipLabel,
    required this.memberCount,
    required this.maxMembers,
    required this.rankLabel,
    required this.ownerUserId,
    required this.quarterCarryExp,
    required this.giftCoinsThisQuarter,
    required this.timeMinutesToday,
  });

  final String id;
  final String name;
  final String minimumVipLabel;
  final int memberCount;
  final int maxMembers;
  final String rankLabel;
  final String ownerUserId;
  final int quarterCarryExp;
  final int giftCoinsThisQuarter;
  final int timeMinutesToday;

  String get avatarText => name.trim().isEmpty ? 'F' : name.trim()[0].toUpperCase();
}

String compactFamilyNumber(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
  return value.toString();
}
