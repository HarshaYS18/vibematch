import '../../models/home_room.dart';

class HomeRoomDto {
  const HomeRoomDto({
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

  factory HomeRoomDto.fromJson(Map<String, dynamic> json) {
    return HomeRoomDto(
      id: json['id']?.toString() ?? json['room_public_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Vibe Room',
      subtitle: json['subtitle']?.toString() ?? '',
      language: json['language']?.toString() ?? 'Other',
      mode: json['mode']?.toString() ?? 'Open',
      type: json['type']?.toString() ?? json['room_type']?.toString() ?? 'Chat',
      onlineCount: _intFromJson(json['online_count']),
      trendingScore: _intFromJson(json['trending_score']),
      followedFriendsInside: _stringListFromJson(json['followed_friends_inside']),
      coverPhotoUrl: _nullableStringFromJson(
        json['cover_photo_url'] ?? json['coverPhotoUrl'] ?? json['avatar_url'],
      ),
    );
  }

  HomeRoom toDomain() {
    return HomeRoom(
      id: id,
      name: name,
      subtitle: subtitle,
      language: language,
      mode: mode,
      type: type,
      onlineCount: onlineCount,
      trendingScore: trendingScore,
      followedFriendsInside: followedFriendsInside,
      coverPhotoUrl: coverPhotoUrl,
    );
  }

  static int _intFromJson(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<String> _stringListFromJson(Object? value) {
    if (value is! List) return const [];
    return value.map((item) => item.toString()).toList();
  }

  static String? _nullableStringFromJson(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text == 'null') return null;
    return text;
  }
}
