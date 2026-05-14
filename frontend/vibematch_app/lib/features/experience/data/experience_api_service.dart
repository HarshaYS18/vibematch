import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';

class ExperienceApiService {
  const ExperienceApiService({AuthApiService authApiService = const AuthApiService()})
      : _authApiService = authApiService;

  final AuthApiService _authApiService;

  Future<Map<String, String>> _headers() async {
    final token = _authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('No auth token available for Experience API. Login first.');
    }
    return {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
  }

  Future<ExperienceProfile> loadMyExperience() async {
    final response = await http.get(Uri.parse(VmApiConfig.endpoint('/experience/me')), headers: await _headers());
    _throwIfFailed(response, 'load my experience');
    return ExperienceProfile.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<ExperienceProfile> loadUserExperienceByPublicId(int publicUserId) async {
    final response = await http.get(Uri.parse(VmApiConfig.endpoint('/experience/users/public/$publicUserId')), headers: await _headers());
    _throwIfFailed(response, 'load user experience');
    return ExperienceProfile.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<RoomExperienceProfile> loadRoomExperience(int roomId) async {
    final response = await http.get(Uri.parse(VmApiConfig.endpoint('/experience/rooms/$roomId')), headers: await _headers());
    _throwIfFailed(response, 'load room experience');
    return RoomExperienceProfile.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<ExperienceTasks> loadTasks() async {
    final response = await http.get(Uri.parse(VmApiConfig.endpoint('/experience/tasks')), headers: await _headers());
    _throwIfFailed(response, 'load experience tasks');
    return ExperienceTasks.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  void _throwIfFailed(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw Exception('Experience API failed to $action (${response.statusCode}): ${response.body}');
  }
}

class ExperienceProfile {
  const ExperienceProfile({
    required this.userId,
    this.publicUserId,
    this.displayName,
    required this.send,
    required this.receive,
  });

  final int userId;
  final int? publicUserId;
  final String? displayName;
  final ExperienceProgress send;
  final ExperienceProgress receive;

  factory ExperienceProfile.fromJson(Map<String, dynamic> json) {
    return ExperienceProfile(
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      publicUserId: (json['public_user_id'] as num?)?.toInt(),
      displayName: json['display_name']?.toString(),
      send: ExperienceProgress.fromJson((json['send'] as Map?)?.cast<String, dynamic>() ?? const {}),
      receive: ExperienceProgress.fromJson((json['receive'] as Map?)?.cast<String, dynamic>() ?? const {}),
    );
  }
}

class RoomExperienceProfile {
  const RoomExperienceProfile({required this.roomId, this.roomName, required this.room});

  final int roomId;
  final String? roomName;
  final ExperienceProgress room;

  factory RoomExperienceProfile.fromJson(Map<String, dynamic> json) {
    return RoomExperienceProfile(
      roomId: (json['room_id'] as num?)?.toInt() ?? 0,
      roomName: json['room_name']?.toString(),
      room: ExperienceProgress.fromJson((json['room'] as Map?)?.cast<String, dynamic>() ?? const {}),
    );
  }
}

class ExperienceProgress {
  const ExperienceProgress({
    required this.level,
    required this.totalExp,
    required this.currentLevelStartExp,
    required this.nextLevelExp,
    required this.expIntoLevel,
    required this.expNeededForNextLevel,
    required this.progress,
    required this.isMaxLevel,
  });

  final int level;
  final int totalExp;
  final int currentLevelStartExp;
  final int nextLevelExp;
  final int expIntoLevel;
  final int expNeededForNextLevel;
  final double progress;
  final bool isMaxLevel;

  factory ExperienceProgress.fromJson(Map<String, dynamic> json) {
    return ExperienceProgress(
      level: (json['level'] as num?)?.toInt() ?? 1,
      totalExp: (json['total_exp'] as num?)?.toInt() ?? 0,
      currentLevelStartExp: (json['current_level_start_exp'] as num?)?.toInt() ?? 0,
      nextLevelExp: (json['next_level_exp'] as num?)?.toInt() ?? 0,
      expIntoLevel: (json['exp_into_level'] as num?)?.toInt() ?? 0,
      expNeededForNextLevel: (json['exp_needed_for_next_level'] as num?)?.toInt() ?? 1,
      progress: ((json['progress'] as num?)?.toDouble() ?? 0).clamp(0, 1),
      isMaxLevel: json['is_max_level'] == true,
    );
  }
}

class ExperienceTasks {
  const ExperienceTasks({required this.sendTasks, required this.receiveTasks, required this.roomTasks, required this.levelRule});

  final List<ExperienceTask> sendTasks;
  final List<ExperienceTask> receiveTasks;
  final List<ExperienceTask> roomTasks;
  final String levelRule;

  factory ExperienceTasks.fromJson(Map<String, dynamic> json) {
    List<ExperienceTask> parse(String key) {
      final raw = json[key];
      if (raw is! List) return const [];
      return raw.whereType<Map>().map((item) => ExperienceTask.fromJson(item.cast<String, dynamic>())).toList();
    }

    return ExperienceTasks(
      sendTasks: parse('send_tasks'),
      receiveTasks: parse('receive_tasks'),
      roomTasks: parse('room_tasks'),
      levelRule: json['level_rule']?.toString() ?? '',
    );
  }
}

class ExperienceTask {
  const ExperienceTask({required this.id, required this.title, required this.description, required this.expRule});

  final String id;
  final String title;
  final String description;
  final String expRule;

  factory ExperienceTask.fromJson(Map<String, dynamic> json) {
    return ExperienceTask(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      expRule: json['exp_rule']?.toString() ?? '',
    );
  }
}
