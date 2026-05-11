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
        return 'Friends';
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
        return 'This user follows you. Tap Follow Back to become friends.';
      case PublicFollowStatus.mutual:
        return 'You both follow each other now. You are friends.';
    }
  }
}

class PublicCoverPhoto {
  const PublicCoverPhoto({required this.imageUrl});
  final String imageUrl;
}

const List<PublicCoverPhoto> publicProfileCoverPhotos = <PublicCoverPhoto>[
  PublicCoverPhoto(imageUrl: ''),
];

List<PublicCoverPhoto> publicCoverPhotosFromUrls(List<String> urls) {
  return urls
      .map((url) => url.trim())
      .where((url) => url.isNotEmpty)
      .map((url) => PublicCoverPhoto(imageUrl: url))
      .toList(growable: false);
}

class PublicVibeItem {
  const PublicVibeItem({
    required this.title,
    required this.mediaType,
    required this.timeAgo,
    required this.body,
    required this.likes,
    required this.comments,
    required this.icon,
    required this.colors,
  });

  final String title;
  final String mediaType;
  final String timeAgo;
  final String body;
  final String likes;
  final String comments;
  final IconData icon;
  final List<Color> colors;
}

const List<PublicVibeItem> mockPublicVibes = <PublicVibeItem>[
  PublicVibeItem(
    title: 'Room Highlights',
    mediaType: 'Photo',
    timeAgo: 'today',
    body: 'Shared a new vibe from the room.',
    likes: '0',
    comments: '0',
    icon: Icons.auto_awesome_rounded,
    colors: <Color>[Color(0xFF6D5DF6), Color(0xFFE84C72)],
  ),
  PublicVibeItem(
    title: 'Live Moments',
    mediaType: 'Video',
    timeAgo: 'recently',
    body: 'A live social moment appears here.',
    likes: '0',
    comments: '0',
    icon: Icons.graphic_eq_rounded,
    colors: <Color>[Color(0xFF12C7B7), Color(0xFF6D5DF6)],
  ),
];
