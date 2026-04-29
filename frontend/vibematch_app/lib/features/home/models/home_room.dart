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
  });

  bool get isSecretVibe => mode.toLowerCase().contains('secret');
  bool get isLocked => mode.toLowerCase().contains('lock');
  bool get isMembersOnly => mode.toLowerCase().contains('member');

  bool get isPublicOpen {
    return !isSecretVibe && !isMembersOnly;
  }
}
