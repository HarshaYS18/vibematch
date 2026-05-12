class HomeRoom {
  final String id;
  final String name;
  final String subtitle;
  final String language;
  final String mode;
  final String type;
  final int onlineCount;
  final int trendingScore;
  final List<String> followedFriendsInside;
  final String? coverPhotoUrl;

  const HomeRoom({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.language,
    required this.mode,
    required this.type,
    required this.onlineCount,
    required this.trendingScore,
    required this.followedFriendsInside,
    this.coverPhotoUrl,
  });

  bool get hasCoverPhoto {
    final value = coverPhotoUrl?.trim();
    return value != null && value.isNotEmpty;
  }

  bool get isPublicOpen {
    return mode.trim().toLowerCase() == 'open' ||
        mode.trim().toLowerCase().contains('sync');
  }

  bool get isSecretVibe {
    return mode.trim().toLowerCase().contains('secret');
  }

  bool get isLocked {
    return mode.trim().toLowerCase().contains('lock');
  }

  bool get isMembersOnly {
    return mode.trim().toLowerCase().contains('member');
  }
}
