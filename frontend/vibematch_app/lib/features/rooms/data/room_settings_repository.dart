import '../../../core/network/api_client.dart';
import '../../auth/data/auth_local_storage.dart';

class RoomSettingsRepository {
  RoomSettingsRepository({ApiClient? apiClient, AuthLocalStorage? authStorage})
    : _apiClient = apiClient ?? ApiClient(),
      _authStorage = authStorage ?? AuthLocalStorage();

  final ApiClient _apiClient;
  final AuthLocalStorage _authStorage;

  Future<RoomSettingsDto> fetchRoomSettings(String roomPublicId) async {
    final response = await _apiClient.getMap('/rooms/$roomPublicId/settings');
    return RoomSettingsDto.fromJson(response);
  }

  Future<RoomSettingsDto> updateAccessSettings({
    required String roomPublicId,
    String? language,
    String? mode,
    String? lockPassword,
    bool? allowScreenshots,
  }) async {
    final response = await _apiClient.patchMap(
      '/rooms/$roomPublicId/settings',
      headers: await _authHeaders(),
      body: {
        'language': ?language,
        'mode': ?mode,
        if (lockPassword != null && lockPassword.trim().isNotEmpty) 'lock_password': lockPassword.trim(),
        'allow_screenshots': ?allowScreenshots,
      },
    );
    return RoomSettingsDto.fromJson(response);
  }

  Future<RoomSettingsDto> updateBackground({
    required String roomPublicId,
    required String backgroundThemeId,
  }) async {
    final response = await _apiClient.patchMap(
      '/rooms/$roomPublicId/background',
      headers: await _authHeaders(),
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
      headers: await _authHeaders(),
      body: {'announcement_text': announcementText},
    );
    return RoomSettingsDto.fromJson(response);
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _authStorage.getAccessToken();
    if (token == null || token.trim().isEmpty) return const <String, String>{};
    return <String, String>{'Authorization': 'Bearer ${token.trim()}'};
  }

  void close() => _apiClient.close();
}

class RoomSettingsDto {
  const RoomSettingsDto({
    required this.roomPublicId,
    required this.backgroundThemeId,
    this.name,
    this.language,
    this.mode,
    this.isSecret = false,
    this.isLocked = false,
    this.isMembersOnly = false,
    this.allowScreenshots = true,
    this.hasLockPassword = false,
    this.announcementText,
    this.announcementUpdatedAt,
    this.announcementUpdatedByUserId,
  });

  final String roomPublicId;
  final String backgroundThemeId;
  final String? name;
  final String? language;
  final String? mode;
  final bool isSecret;
  final bool isLocked;
  final bool isMembersOnly;
  final bool allowScreenshots;
  final bool hasLockPassword;
  final String? announcementText;
  final DateTime? announcementUpdatedAt;
  final int? announcementUpdatedByUserId;

  factory RoomSettingsDto.fromJson(Map<String, dynamic> json) {
    return RoomSettingsDto(
      roomPublicId: json['room_public_id']?.toString() ?? '',
      backgroundThemeId: json['background_theme_id']?.toString() ?? 'default',
      name: _nullableString(json['name']),
      language: _nullableString(json['language']),
      mode: _nullableString(json['mode']),
      isSecret: json['is_secret'] == true,
      isLocked: json['is_locked'] == true,
      isMembersOnly: json['is_members_only'] == true,
      allowScreenshots: json['allow_screenshots'] != false,
      hasLockPassword: json['has_lock_password'] == true,
      announcementText: json['announcement_text']?.toString(),
      announcementUpdatedAt: DateTime.tryParse(json['announcement_updated_at']?.toString() ?? ''),
      announcementUpdatedByUserId: int.tryParse(json['announcement_updated_by_user_id']?.toString() ?? ''),
    );
  }
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty || text == 'null') return null;
  return text;
}
