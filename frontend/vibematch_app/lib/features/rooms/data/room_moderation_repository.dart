import '../../../core/network/api_client.dart';

class RoomModerationRepository {
  RoomModerationRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

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

  void close() {
    _apiClient.close();
  }
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
