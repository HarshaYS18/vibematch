class RankingPayload {
  const RankingPayload({
    required this.rankingType,
    required this.period,
    required this.generatedAt,
    required this.entries,
  });

  final String rankingType;
  final String period;
  final String generatedAt;
  final List<RankingEntry> entries;

  factory RankingPayload.fromJson(Map<String, dynamic> json) {
    final rows = json['entries'] as List<dynamic>? ?? const [];
    return RankingPayload(
      rankingType: json['ranking_type']?.toString() ?? '',
      period: json['period']?.toString() ?? '',
      generatedAt: json['generated_at']?.toString() ?? '',
      entries: rows.whereType<Map<String, dynamic>>().map(RankingEntry.fromJson).toList(),
    );
  }
}

class RankingEntry {
  const RankingEntry({
    required this.rank,
    required this.score,
    required this.scoreDisplay,
    required this.user,
  });

  final int rank;
  final int score;
  final String scoreDisplay;
  final RankingUser user;

  factory RankingEntry.fromJson(Map<String, dynamic> json) => RankingEntry(
        rank: _int(json['rank']),
        score: _int(json['score']),
        scoreDisplay: json['score_display']?.toString() ?? _compact(_int(json['score'])),
        user: RankingUser.fromJson((json['user'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{}),
      );
}

class RankingUser {
  const RankingUser({
    required this.publicUserId,
    required this.displayName,
    required this.username,
    required this.avatarUrl,
    required this.vipLevel,
    required this.svipLevel,
    required this.sendLevel,
    required this.receiveLevel,
  });

  final int publicUserId;
  final String displayName;
  final String? username;
  final String? avatarUrl;
  final int vipLevel;
  final int svipLevel;
  final int sendLevel;
  final int receiveLevel;

  String get initials {
    final clean = displayName.trim();
    if (clean.isEmpty) return 'VM';
    return clean.length <= 2 ? clean.toUpperCase() : clean.substring(0, 2).toUpperCase();
  }

  factory RankingUser.fromJson(Map<String, dynamic> json) {
    final publicId = _int(json['public_user_id']);
    final name = json['display_name']?.toString().trim();
    return RankingUser(
      publicUserId: publicId,
      displayName: name == null || name.isEmpty ? 'User $publicId' : name,
      username: _string(json['username']),
      avatarUrl: _string(json['avatar_url']),
      vipLevel: _int(json['vip_level']),
      svipLevel: _int(json['svip_level']),
      sendLevel: _int(json['send_level']),
      receiveLevel: _int(json['receive_level']),
    );
  }
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

String? _string(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty || text == 'null') return null;
  return text;
}

String _compact(int value) {
  if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(1)}B';
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return '$value';
}
