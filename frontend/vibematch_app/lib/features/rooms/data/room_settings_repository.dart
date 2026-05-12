import '../../../core/network/api_client.dart';

class RoomSettingsRepository {
  RoomSettingsRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<RoomSettingsDto> fetchRoomSettings(String roomPublicId) async {
    final response = await _apiClient.getMap('/rooms/$roomPublicId/settings');
    return RoomSettingsDto.fromJson(response);
  }

  Future<RoomSettingsDto> updateBackground({
    required String roomPublicId,
    required String backgroundThemeId,
  }) async {
    final response = await _apiClient.patchMap(
      '/rooms/$roomPublicId/background',
      body: {'background_theme_id': backgroundThemeId},
    );
    return RoomSettingsDto.fromJson(response);
  }

  Future<RoomSettingsDto> updateAnnouncement({
    required String roomPublicId,
    required String announcementText,
  }) async {
    final response = await _apiClient.patchMap(
      '/rooms/$roomPublicId/announcement',
      body: {'announcement_text': announcementText},
    );
    return RoomSettingsDto.fromJson(response);
  }

  void close() => _apiClient.close();
}

class RoomSettingsDto {
  const RoomSettingsDto({
    required this.roomPublicId,
    required this.backgroundThemeId,
    this.announcementText,
    this.announcementUpdatedAt,
    this.announcementUpdatedByUserId,
  });

  final String roomPublicId;
  final String backgroundThemeId;
  final String? announcementText;
  final DateTime? announcementUpdatedAt;
  final int? announcementUpdatedByUserId;

  factory RoomSettingsDto.fromJson(Map<String, dynamic> json) {
    return RoomSettingsDto(
      roomPublicId: json['room_public_id']?.toString() ?? '',
      backgroundThemeId: json['background_theme_id']?.toString() ?? 'default',
      announcementText: json['announcement_text']?.toString(),
      announcementUpdatedAt: DateTime.tryParse(
        json['announcement_updated_at']?.toString() ?? '',
      ),
      announcementUpdatedByUserId: int.tryParse(
        json['announcement_updated_by_user_id']?.toString() ?? '',
      ),
    );
  }
}
