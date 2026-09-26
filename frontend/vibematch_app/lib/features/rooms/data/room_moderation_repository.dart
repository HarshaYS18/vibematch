import 'package:vibematch_app/foundation/networking/app_network_client.dart';

class RoomModerationRepository {
  RoomModerationRepository({AppNetworkClient? apiClient}) : _apiClient = apiClient ?? AppNetworkRuntime.shared;

  final AppNetworkClient _apiClient;

  Future<void> kickOutUser({
    required String roomId,
    required String targetUserId,
    required String targetDisplayName,
    required RoomKickoutDuration duration,
    String? reason,
  }) async {
    await _apiClient.postMap(
      '/rooms/$roomId/kickouts',
      body: {
        'target_public_user_id': targetUserId,
        'target_display_name': targetDisplayName,
        'duration': duration.apiValue,
        'reason': reason,
      },
    );
  }

  Future<List<RoomBlockedUserDto>> listBlockedUsers({
    required String roomId,
  }) async {
    final response = await _apiClient.getList('/rooms/$roomId/kickouts');
    return response
        .whereType<Map<String, dynamic>>()
        .map(RoomBlockedUserDto.fromJson)
        .toList(growable: false);
  }

  Future<void> unblockUser({
    required String roomId,
    required int kickoutId,
  }) async {
    await _apiClient.deleteMap('/rooms/$roomId/kickouts/$kickoutId');
  }

  void close() {
    _apiClient.close();
  }
}

class RoomBlockedUserDto {
  const RoomBlockedUserDto({
    required this.id,
    required this.roomPublicId,
    required this.duration,
    required this.isPermanent,
    required this.isActive,
    required this.createdAt,
    this.targetUserId,
    this.targetPublicUserId,
    this.targetDisplayName,
    this.createdByUserId,
    this.createdByPublicUserId,
    this.blockedUntil,
  });

  final int id;
  final String roomPublicId;
  final int? targetUserId;
  final String? targetPublicUserId;
  final String? targetDisplayName;
  final int? createdByUserId;
  final String? createdByPublicUserId;
  final String duration;
  final DateTime? blockedUntil;
  final bool isPermanent;
  final bool isActive;
  final DateTime createdAt;

  factory RoomBlockedUserDto.fromJson(Map<String, dynamic> json) {
    return RoomBlockedUserDto(
      id: json['id'] as int? ?? 0,
      roomPublicId: json['room_public_id'] as String? ?? '',
      targetUserId: json['target_user_id'] as int?,
      targetPublicUserId: json['target_public_user_id'] as String?,
      targetDisplayName: json['target_display_name'] as String?,
      createdByUserId: json['created_by_user_id'] as int?,
      createdByPublicUserId: json['created_by_public_user_id'] as String?,
      duration: json['duration'] as String? ?? '',
      blockedUntil: _dateTimeFromJson(json['blocked_until']),
      isPermanent: json['is_permanent'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? false,
      createdAt: _dateTimeFromJson(json['created_at']) ?? DateTime.now(),
    );
  }

  String get displayName {
    final name = targetDisplayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final publicId = targetPublicUserId?.trim();
    if (publicId != null && publicId.isNotEmpty) return 'User $publicId';
    return 'Blocked User';
  }

  String get publicUserIdLabel {
    final publicId = targetPublicUserId?.trim();
    if (publicId != null && publicId.isNotEmpty) return publicId;
    final internalId = targetUserId;
    if (internalId != null) return '$internalId';
    return 'Unknown';
  }

  String get durationLabel {
    switch (duration) {
      case '1h':
        return '1 Hour';
      case '1d':
        return '1 Day';
      case 'forever':
        return 'Forever';
      default:
        return duration.isEmpty ? 'Active' : duration;
    }
  }

  String get blockedByLabel {
    final publicId = createdByPublicUserId?.trim();
    if (publicId != null && publicId.isNotEmpty) return publicId;
    final internalId = createdByUserId;
    if (internalId != null) return '$internalId';
    return 'Room admin';
  }

  String get blockedAtLabel {
    final now = DateTime.now();
    final difference = now.difference(createdAt.toLocal());

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
    if (difference.inHours < 24) return '${difference.inHours} hr ago';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 30) return '${difference.inDays} days ago';
    return '${createdAt.toLocal().day}/${createdAt.toLocal().month}/${createdAt.toLocal().year}';
  }

  bool get isForever => isPermanent || duration == 'forever';
}

DateTime? _dateTimeFromJson(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value);
}

enum RoomKickoutDuration {
  oneHour,
  oneDay,
  forever;

  String get apiValue {
    switch (this) {
      case RoomKickoutDuration.oneHour:
        return '1h';
      case RoomKickoutDuration.oneDay:
        return '1d';
      case RoomKickoutDuration.forever:
        return 'forever';
    }
  }

  String get label {
    switch (this) {
      case RoomKickoutDuration.oneHour:
        return '1 Hour';
      case RoomKickoutDuration.oneDay:
        return '1 Day';
      case RoomKickoutDuration.forever:
        return 'Forever';
    }
  }

  String get description {
    switch (this) {
      case RoomKickoutDuration.oneHour:
        return 'User cannot re-enter this room for 1 hour.';
      case RoomKickoutDuration.oneDay:
        return 'User cannot re-enter this room for 1 day.';
      case RoomKickoutDuration.forever:
        return 'User stays blocked until removed from room settings.';
    }
  }
}
