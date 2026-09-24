import 'dart:convert';

import 'package:vibematch_app/foundation/networking/feature_http_compat.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';

class InboxPreferenceSettings {
  const InboxPreferenceSettings({
    required this.strangersCanMessage,
    required this.strangersCanMentionInVibes,
    required this.readReceiptsEnabled,
    required this.onlineVisibility,
    required this.lastSeenVisibility,
    required this.typingActivityVisibility,
    required this.storyVisibility,
    required this.deviceUnlockEnabled,
    required this.defaultChatTheme,
    required this.defaultWallpaperKey,
    this.defaultWallpaperUrl,
  });

  final bool strangersCanMessage;
  final bool strangersCanMentionInVibes;
  final bool readReceiptsEnabled;
  final String onlineVisibility;
  final String lastSeenVisibility;
  final String typingActivityVisibility;
  final String storyVisibility;
  final bool deviceUnlockEnabled;
  final String defaultChatTheme;
  final String defaultWallpaperKey;
  final String? defaultWallpaperUrl;

  InboxPreferenceSettings copyWith({
    bool? strangersCanMessage,
    bool? strangersCanMentionInVibes,
    bool? readReceiptsEnabled,
    String? onlineVisibility,
    String? lastSeenVisibility,
    String? typingActivityVisibility,
    String? storyVisibility,
    bool? deviceUnlockEnabled,
    String? defaultChatTheme,
    String? defaultWallpaperKey,
    String? defaultWallpaperUrl,
  }) {
    return InboxPreferenceSettings(
      strangersCanMessage: strangersCanMessage ?? this.strangersCanMessage,
      strangersCanMentionInVibes: strangersCanMentionInVibes ?? this.strangersCanMentionInVibes,
      readReceiptsEnabled: readReceiptsEnabled ?? this.readReceiptsEnabled,
      onlineVisibility: onlineVisibility ?? this.onlineVisibility,
      lastSeenVisibility: lastSeenVisibility ?? this.lastSeenVisibility,
      typingActivityVisibility: typingActivityVisibility ?? this.typingActivityVisibility,
      storyVisibility: storyVisibility ?? this.storyVisibility,
      deviceUnlockEnabled: deviceUnlockEnabled ?? this.deviceUnlockEnabled,
      defaultChatTheme: defaultChatTheme ?? this.defaultChatTheme,
      defaultWallpaperKey: defaultWallpaperKey ?? this.defaultWallpaperKey,
      defaultWallpaperUrl: defaultWallpaperUrl ?? this.defaultWallpaperUrl,
    );
  }

  Map<String, Object?> toApiJson() => <String, Object?>{
        'strangers_can_message': strangersCanMessage,
        'strangers_can_mention_in_vibes': strangersCanMentionInVibes,
        'read_receipts_enabled': readReceiptsEnabled,
        'online_visibility': onlineVisibility,
        'last_seen_visibility': lastSeenVisibility,
        'typing_activity_visibility': typingActivityVisibility,
        'story_visibility': storyVisibility,
        'device_unlock_enabled': deviceUnlockEnabled,
        'default_chat_theme': defaultChatTheme,
        'default_wallpaper_key': defaultWallpaperKey,
        'default_wallpaper_url': defaultWallpaperUrl,
      };

  static InboxPreferenceSettings fromJson(Map<String, dynamic> json) {
    return InboxPreferenceSettings(
      strangersCanMessage: json['strangers_can_message'] != false,
      strangersCanMentionInVibes: json['strangers_can_mention_in_vibes'] != false,
      readReceiptsEnabled: json['read_receipts_enabled'] != false,
      onlineVisibility: json['online_visibility']?.toString() ?? 'everyone',
      lastSeenVisibility: json['last_seen_visibility']?.toString() ?? 'everyone',
      typingActivityVisibility: json['typing_activity_visibility']?.toString() ?? 'everyone',
      storyVisibility: json['story_visibility']?.toString() ?? 'friends',
      deviceUnlockEnabled: json['device_unlock_enabled'] == true,
      defaultChatTheme: json['default_chat_theme']?.toString() ?? 'pearl',
      defaultWallpaperKey: json['default_wallpaper_key']?.toString() ?? 'premium_pearl',
      defaultWallpaperUrl: _nullable(json['default_wallpaper_url']),
    );
  }

  static String? _nullable(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}

class InboxPreferencesApiService {
  const InboxPreferencesApiService({AuthApiService authApiService = const AuthApiService()}) : _authApiService = authApiService;

  final AuthApiService _authApiService;

  Future<Map<String, String>> _headers() async {
    final token = _authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('No auth token available for Inbox preferences. Login first.');
    }
    return <String, String>{'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
  }

  Future<InboxPreferenceSettings> loadPreferences() async {
    final response = await http.get(Uri.parse(VmApiConfig.endpoint('/inbox/preferences')), headers: await _headers());
    _throwIfFailed(response, 'load preferences');
    return InboxPreferenceSettings.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<InboxPreferenceSettings> updatePreferences(InboxPreferenceSettings settings) async {
    final response = await http.patch(
      Uri.parse(VmApiConfig.endpoint('/inbox/preferences')),
      headers: await _headers(),
      body: jsonEncode(settings.toApiJson()),
    );
    _throwIfFailed(response, 'update preferences');
    return InboxPreferenceSettings.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> updateConversationTheme({
    required String conversationId,
    required String chatTheme,
    required String wallpaperKey,
    String? wallpaperUrl,
  }) async {
    final response = await http.patch(
      Uri.parse(VmApiConfig.endpoint('/inbox/conversations/$conversationId/theme')),
      headers: await _headers(),
      body: jsonEncode(<String, Object?>{
        'chat_theme': chatTheme,
        'wallpaper_key': wallpaperKey,
        'wallpaper_url': wallpaperUrl,
      }),
    );
    _throwIfFailed(response, 'update chat theme');
  }

  void _throwIfFailed(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw Exception('Inbox preferences failed to $action (${response.statusCode}): ${response.body}');
  }
}
