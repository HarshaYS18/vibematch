import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'control_center_models.dart';

class ControlCenterStore {
  const ControlCenterStore._();

  static const String _stateKey = 'vm_control_center.state';

  static Future<ControlCenterState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_stateKey);
    if (raw == null || raw.trim().isEmpty) return _defaultState();

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return ControlCenterState(
        globalInvisible: json['global_invisible'] == true,
        hideFromOnlineCount: json['hide_from_online_count'] == true,
        hideWhenSeated: json['hide_when_seated'] == true,
        hideRoomEntryEvents: json['hide_room_entry_events'] == true,
        auditInvisibleAccess: json['audit_invisible_access'] != false,
        coinAuthorityBalance: int.tryParse(json['coin_authority_balance']?.toString() ?? '') ?? 5000000,
        logs: _decodeLogs(json['logs']),
        powerGrants: _decodePowerGrants(json['power_grants']),
        reviewItems: _defaultReviewItems(),
      );
    } catch (_) {
      return _defaultState();
    }
  }

  static Future<void> save(ControlCenterState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stateKey, jsonEncode(<String, dynamic>{
      'global_invisible': state.globalInvisible,
      'hide_from_online_count': state.hideFromOnlineCount,
      'hide_when_seated': state.hideWhenSeated,
      'hide_room_entry_events': state.hideRoomEntryEvents,
      'audit_invisible_access': state.auditInvisibleAccess,
      'coin_authority_balance': state.coinAuthorityBalance,
      'logs': state.logs.map((log) => log.toJson()).toList(),
      'power_grants': state.powerGrants.map((grant) => grant.toJson()).toList(),
    }));
  }

  static Future<ControlCenterState> writeLog(
    ControlCenterState state, {
    required String action,
    required String targetUserId,
    required String chatRoomId,
    required String resourceType,
    required String reason,
  }) async {
    final now = DateTime.now();
    final log = ControlLogEntry(
      id: 'LOG-${now.millisecondsSinceEpoch}',
      actorUserId: '6922022',
      targetUserId: targetUserId,
      chatRoomId: chatRoomId,
      action: action,
      resourceType: resourceType,
      reason: reason,
      createdAt: now,
    );
    final next = state.copyWith(logs: <ControlLogEntry>[log, ...state.logs].take(80).toList());
    await save(next);
    return next;
  }

  static ControlCenterState _defaultState() {
    return ControlCenterState(
      globalInvisible: false,
      hideFromOnlineCount: true,
      hideWhenSeated: true,
      hideRoomEntryEvents: true,
      auditInvisibleAccess: true,
      coinAuthorityBalance: 5000000,
      logs: _defaultLogs(),
      powerGrants: const <PowerGrantEntry>[],
      reviewItems: _defaultReviewItems(),
    );
  }

  static List<ControlLogEntry> _defaultLogs() {
    final now = DateTime.now();
    return <ControlLogEntry>[
      ControlLogEntry(id: 'LOG-SEED-1', actorUserId: '6922022', targetUserId: '6418000091', chatRoomId: 'VM257808', action: 'ROOM_REVIEWED', resourceType: 'chat_room', reason: 'Room quality review seed log', createdAt: now.subtract(const Duration(minutes: 18))),
      ControlLogEntry(id: 'LOG-SEED-2', actorUserId: '6922022', targetUserId: '6418000022', chatRoomId: 'VM100204', action: 'TEMP_BAN_USER', resourceType: 'user_ban', reason: 'Abuse report review seed log', createdAt: now.subtract(const Duration(hours: 2))),
      ControlLogEntry(id: 'LOG-SEED-3', actorUserId: '6922022', targetUserId: '6418000077', chatRoomId: 'VM777888', action: 'CUSTOM_ID_ASSIGNED', resourceType: 'identity', reason: 'Premium ID assignment seed log', createdAt: now.subtract(const Duration(hours: 5))),
    ];
  }

  static List<ReviewQueueItem> _defaultReviewItems() {
    final now = DateTime.now();
    return <ReviewQueueItem>[
      ReviewQueueItem(id: 'REV-1001', type: 'custom_theme', title: 'Custom room background review', userId: '6418000091', roomId: 'VM257808', status: 'Pending', createdAt: now.subtract(const Duration(minutes: 34))),
      ReviewQueueItem(id: 'REV-1002', type: 'report', title: 'Harassment report escalation', userId: '6418000044', roomId: 'VM100204', status: 'Pending', createdAt: now.subtract(const Duration(hours: 3))),
      ReviewQueueItem(id: 'REV-1003', type: 'dp_review', title: 'Profile photo safety review', userId: '6418000033', roomId: '-', status: 'Pending', createdAt: now.subtract(const Duration(hours: 7))),
    ];
  }

  static List<ControlLogEntry> _decodeLogs(dynamic raw) {
    if (raw is! List) return _defaultLogs();
    return raw.whereType<Map>().map((item) => ControlLogEntry.fromJson(Map<String, dynamic>.from(item))).toList();
  }

  static List<PowerGrantEntry> _decodePowerGrants(dynamic raw) {
    if (raw is! List) return const <PowerGrantEntry>[];
    return raw.whereType<Map>().map((item) => PowerGrantEntry.fromJson(Map<String, dynamic>.from(item))).toList();
  }
}
