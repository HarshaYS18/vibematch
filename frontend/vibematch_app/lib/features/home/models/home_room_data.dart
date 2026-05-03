class HomeRoomData {
  const HomeRoomData({
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

  bool get isSecretVibe => mode.toLowerCase().contains('secret');
  bool get isPublicOpen => !isSecretVibe && !mode.toLowerCase().contains('member');

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'subtitle': subtitle,
      'language': language,
      'mode': mode,
      'type': type,
      'onlineCount': onlineCount,
      'trendingScore': trendingScore,
      'followedFriendsInside': followedFriendsInside,
    };
  }

  factory HomeRoomData.fromJson(Map<String, Object?> json) {
    return HomeRoomData(
      id: json['id']?.toString() ?? 'VM000000',
      name: json['name']?.toString() ?? 'My Room',
      subtitle: json['subtitle']?.toString() ?? 'Your live room',
      language: json['language']?.toString() ?? 'English',
      mode: json['mode']?.toString() ?? 'Open',
      type: json['type']?.toString() ?? 'Chat',
      onlineCount: int.tryParse(json['onlineCount']?.toString() ?? '') ?? 1,
      trendingScore: int.tryParse(json['trendingScore']?.toString() ?? '') ?? 0,
      followedFriendsInside: (json['followedFriendsInside'] is List)
          ? List<String>.from(json['followedFriendsInside'] as List)
          : const [],
    );
  }
}
