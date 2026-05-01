class HomeRoomModel {
  const HomeRoomModel({
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

  final String id;
  final String name;
  final String subtitle;
  final String language;
  final String mode;
  final String type;
  final int onlineCount;
  final int trendingScore;
  final List<String> followedFriendsInside;

  bool get isHiddenMode => mode.toLowerCase().contains('secret');
  bool get isLockedMode => mode.toLowerCase().contains('lock');
  bool get isMembersMode => mode.toLowerCase().contains('member');
  bool get isPublicOpen => !isHiddenMode && !isMembersMode;
}
