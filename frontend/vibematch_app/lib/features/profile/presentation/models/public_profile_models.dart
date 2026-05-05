import 'package:flutter/material.dart';

import '../../../../core/icons/vm_icons.dart';

enum PublicFollowStatus {
  none,
  following,
  followBack,
  mutual;

  String get label {
    switch (this) {
      case PublicFollowStatus.none:
        return 'Follow';
      case PublicFollowStatus.following:
        return 'Following';
      case PublicFollowStatus.followBack:
        return 'Follow Back';
      case PublicFollowStatus.mutual:
        return 'Mutual';
    }
  }

  IconData get icon {
    switch (this) {
      case PublicFollowStatus.none:
        return VMIcons.userAdd;
      case PublicFollowStatus.following:
        return VMIcons.verifiedUser;
      case PublicFollowStatus.followBack:
        return VMIcons.userAdd;
      case PublicFollowStatus.mutual:
        return VMIcons.friends;
    }
  }

  String get message {
    switch (this) {
      case PublicFollowStatus.none:
        return 'Unfollowed this profile.';
      case PublicFollowStatus.following:
        return 'You are now following this profile.';
      case PublicFollowStatus.followBack:
        return 'This user follows you. Tap Follow Back to become mutual.';
      case PublicFollowStatus.mutual:
        return 'You both follow each other now.';
    }
  }
}

class PublicCoverPhoto {
  const PublicCoverPhoto({
    required this.title,
    required this.colors,
    required this.icon,
  });

  final String title;
  final List<Color> colors;
  final IconData icon;
}

class PublicVibeItem {
  const PublicVibeItem({
    required this.title,
    required this.body,
    required this.timeAgo,
    required this.mediaType,
    required this.tag,
    required this.likes,
    required this.comments,
    required this.icon,
    required this.colors,
  });

  final String title;
  final String body;
  final String timeAgo;
  final String mediaType;
  final String tag;
  final String likes;
  final String comments;
  final IconData icon;
  final List<Color> colors;
}

const List<PublicCoverPhoto> publicProfileCoverPhotos = [
  PublicCoverPhoto(
    title: 'Royal Vibe',
    colors: [
      Color(0xFF251538),
      Color(0xFF6D5DF6),
      Color(0xFFE84C72),
    ],
    icon: VMIcons.sparkle,
  ),
  PublicCoverPhoto(
    title: 'Music Night',
    colors: [
      Color(0xFF064D46),
      Color(0xFF12C7B7),
      Color(0xFFFFD36A),
    ],
    icon: VMIcons.music,
  ),
  PublicCoverPhoto(
    title: 'Family Moment',
    colors: [
      Color(0xFF5C102B),
      Color(0xFFE84C72),
      Color(0xFFFFC857),
    ],
    icon: VMIcons.users,
  ),
];

const List<PublicVibeItem> mockPublicVibes = [
  PublicVibeItem(
    title: 'Late night room memories',
    body: 'Good songs, good friends, and a calm room vibe tonight.',
    timeAgo: '2h ago',
    mediaType: 'Photo',
    tag: 'Room',
    likes: '1.2K',
    comments: '86',
    icon: VMIcons.photo,
    colors: [
      Color(0xFF12C7B7),
      Color(0xFF6D5DF6),
    ],
  ),
  PublicVibeItem(
    title: 'Vibe Sync clip',
    body: 'The audience matched the beat perfectly in Vibe Sync.',
    timeAgo: '8h ago',
    mediaType: 'Video',
    tag: 'Vibe Sync',
    likes: '856',
    comments: '42',
    icon: VMIcons.play,
    colors: [
      Color(0xFFE84C72),
      Color(0xFFFFD36A),
    ],
  ),
  PublicVibeItem(
    title: 'Family event ready',
    body: 'Moon Fam is preparing for the next family event and rewards.',
    timeAgo: '1d ago',
    mediaType: 'Photo',
    tag: 'Family',
    likes: '642',
    comments: '31',
    icon: VMIcons.users,
    colors: [
      Color(0xFF6D5DF6),
      Color(0xFFE84C72),
    ],
  ),
];
