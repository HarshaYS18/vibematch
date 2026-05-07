import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';
import '../models/inbox_models.dart';

class InboxBackupApiService {
  const InboxBackupApiService({AuthApiService authApiService = const AuthApiService()})
      : _authApiService = authApiService;

  final AuthApiService _authApiService;

  Future<Map<String, String>> _headers() async {
    final token = _authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('No auth token available for Inbox backup API. Login first.');
    }
    return {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
  }

  Future<InboxBackupStatus> loadStatus() async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/inbox/backup/status')),
      headers: await _headers(),
    );
    _throwIfFailed(response, 'load backup status');
    return backupStatusFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<InboxBackupStatus> updateSettings({bool? isEnabled, ChatBackupFrequency? frequency}) async {
    final response = await http.patch(
      Uri.parse(VmApiConfig.endpoint('/inbox/backup/settings')),
      headers: await _headers(),
      body: jsonEncode({
        if (isEnabled != null) 'is_enabled': isEnabled,
        if (frequency != null) 'frequency': frequency.apiValue,
      }),
    );
    _throwIfFailed(response, 'update backup settings');
    return backupStatusFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<String> loadGoogleDriveSetupUrl() async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/inbox/backup/google/authorize')),
      headers: await _headers(),
    );
    _throwIfFailed(response, 'start Google Drive setup');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['authorization_url']?.toString() ?? '';
  }

  Future<InboxBackupStatus> connectGoogleDrive({String? googleDriveEmail, String? setupCode}) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/inbox/backup/google/connect')),
      headers: await _headers(),
      body: jsonEncode({
        if (googleDriveEmail != null) 'google_drive_email': googleDriveEmail,
        if (setupCode != null) 'authorization_code': setupCode,
      }),
    );
    _throwIfFailed(response, 'connect Google Drive');
    return backupStatusFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<InboxBackupJob> runBackupNow() async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/inbox/backup/run')),
      headers: await _headers(),
    );
    _throwIfFailed(response, 'run backup');
    return backupJobFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<InboxBackupJob> restoreLatestBackup() async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/inbox/backup/restore')),
      headers: await _headers(),
    );
    _throwIfFailed(response, 'restore backup');
    return backupJobFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  void _throwIfFailed(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw Exception('Inbox backup API failed to $action (${response.statusCode}): ${response.body}');
  }

  InboxBackupStatus backupStatusFromJson(Map<String, dynamic> json) {
    return InboxBackupStatus(
      isEnabled: json['is_enabled'] == true,
      isAuthorized: json['is_authorized'] == true,
      provider: json['provider']?.toString() ?? 'google_drive',
      frequency: ChatBackupFrequency.fromApi(json['frequency']?.toString()),
      googleDriveEmail: json['google_drive_email']?.toString(),
      googleDriveFolderId: json['google_drive_folder_id']?.toString(),
      lastBackupAt: json['last_backup_at']?.toString(),
      lastRestoreAt: json['last_restore_at']?.toString(),
      lastStatus: json['last_status']?.toString() ?? 'not_connected',
      lastError: json['last_error']?.toString(),
      backupCount: (json['backup_count'] as num?)?.toInt() ?? 0,
      restoreCount: (json['restore_count'] as num?)?.toInt() ?? 0,
    );
  }

  InboxBackupJob backupJobFromJson(Map<String, dynamic> json) {
    return InboxBackupJob(
      id: json['id']?.toString() ?? '',
      jobType: json['job_type']?.toString() ?? '',
      provider: json['provider']?.toString() ?? 'google_drive',
      status: json['status']?.toString() ?? '',
      backupFileId: json['backup_file_id']?.toString(),
      backupFileName: json['backup_file_name']?.toString(),
      errorMessage: json['error_message']?.toString(),
      createdAt: json['created_at']?.toString(),
      completedAt: json['completed_at']?.toString(),
    );
  }
}
