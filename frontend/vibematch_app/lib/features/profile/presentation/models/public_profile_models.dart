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

List<PublicCoverPhoto> publicCoverPhotosFromUrls(List<String> urls) {
  return urls
      .map((url) => url.trim())
      .where((url) => url.isNotEmpty)
      .map((url) => PublicCoverPhoto(imageUrl: url))
      .toList(growable: false);
}
