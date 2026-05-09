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
        reviewItems: _decodeReviewItems(json['review_items']),
        roleAssignments: _decodeRoleAssignments(json['role_assignments']),
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
      'role_assignments': state.roleAssignments.map((role) => role.toJson()).toList(),
      'review_items': state.reviewItems.map(_reviewToJson).toList(),
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
    final next = state.copyWith(logs: <ControlLogEntry>[log, ...state.logs].take(120).toList());
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
      roleAssignments: _defaultRoleAssignments(),
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

  static List<RoleAssignmentEntry> _defaultRoleAssignments() {
    final now = DateTime.now();
    return <RoleAssignmentEntry>[
      RoleAssignmentEntry(id: 'ROLE-SEED-1', userId: '6418000101', role: 'monitor', assignedByUserId: '6922022', reason: 'Seed monitor team role', isActive: true, createdAt: now.subtract(const Duration(days: 2))),
      RoleAssignmentEntry(id: 'ROLE-SEED-2', userId: '6418000112', role: 'cs', assignedByUserId: '6922022', reason: 'Seed CS review role', isActive: true, createdAt: now.subtract(const Duration(days: 5))),
    ];
  }

  static List<ReviewQueueItem> _defaultReviewItems() {
    final now = DateTime.now();
    return <ReviewQueueItem>[
      ReviewQueueItem(
        id: 'REV-1001',
        type: 'custom_theme',
        title: 'Custom room background review',
        userId: '6418000091',
        roomId: 'VM257808',
        status: 'Pending',
        createdAt: now.subtract(const Duration(minutes: 34)),
        mappedOfficialRole: 'monitor',
        mappedOfficialName: 'Asha Monitor',
        mappedOfficialUserId: '6418000101',
        mappedAt: now.subtract(const Duration(minutes: 29)),
        issueDetails: 'User uploaded a dark room background. Need check for watermark, vulgar content, and brand safety before auto-apply.',
        priority: 'High',
        evidenceLabel: 'Image upload + room id + submitter id',
      ),
      ReviewQueueItem(
        id: 'REV-1002',
        type: 'report',
        title: 'Harassment report escalation',
        userId: '6418000044',
        roomId: 'VM100204',
        status: 'Pending',
        createdAt: now.subtract(const Duration(hours: 3)),
        mappedOfficialRole: 'cs',
        mappedOfficialName: 'CS Kavya',
        mappedOfficialUserId: '6418000112',
        mappedAt: now.subtract(const Duration(hours: 2, minutes: 42)),
        issueDetails: 'Three users reported repeated abusive mic behavior. CS should verify room logs and escalate to Monitor if confirmed.',
        priority: 'Urgent',
        evidenceLabel: 'Report bundle + chatroom id + latest room events',
      ),
      ReviewQueueItem(
        id: 'REV-1003',
        type: 'dp_review',
        title: 'Profile photo safety review',
        userId: '6418000033',
        roomId: '-',
        status: 'Pending',
        createdAt: now.subtract(const Duration(hours: 7)),
        mappedOfficialRole: 'monitor',
        mappedOfficialName: 'Ravi Monitor',
        mappedOfficialUserId: '6418000109',
        mappedAt: now.subtract(const Duration(hours: 6, minutes: 50)),
        issueDetails: 'Avatar moderation flagged possible vulgar profile image. Verify manually and decide approve/reject/account warning.',
        priority: 'Medium',
        evidenceLabel: 'Avatar snapshot + moderation flag',
      ),
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

  static List<RoleAssignmentEntry> _decodeRoleAssignments(dynamic raw) {
    if (raw is! List) return _defaultRoleAssignments();
    return raw.whereType<Map>().map((item) => RoleAssignmentEntry.fromJson(Map<String, dynamic>.from(item))).toList();
  }

  static List<ReviewQueueItem> _decodeReviewItems(dynamic raw) {
    if (raw is! List) return _defaultReviewItems();
    return raw.whereType<Map>().map((item) => _reviewFromJson(Map<String, dynamic>.from(item))).toList();
  }

  static Map<String, dynamic> _reviewToJson(ReviewQueueItem item) => <String, dynamic>{
        'id': item.id,
        'type': item.type,
        'title': item.title,
        'user_id': item.userId,
        'room_id': item.roomId,
        'status': item.status,
        'created_at': item.createdAt.toIso8601String(),
        'mapped_official_role': item.mappedOfficialRole,
        'mapped_official_name': item.mappedOfficialName,
        'mapped_official_user_id': item.mappedOfficialUserId,
        'mapped_at': item.mappedAt.toIso8601String(),
        'issue_details': item.issueDetails,
        'priority': item.priority,
        'evidence_label': item.evidenceLabel,
      };

  static ReviewQueueItem _reviewFromJson(Map<String, dynamic> json) => ReviewQueueItem(
        id: json['id']?.toString() ?? '',
        type: json['type']?.toString() ?? 'review',
        title: json['title']?.toString() ?? 'Review task',
        userId: json['user_id']?.toString() ?? '-',
        roomId: json['room_id']?.toString() ?? '-',
        status: json['status']?.toString() ?? 'Pending',
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
        mappedOfficialRole: json['mapped_official_role']?.toString() ?? 'monitor',
        mappedOfficialName: json['mapped_official_name']?.toString() ?? 'Monitor Team',
        mappedOfficialUserId: json['mapped_official_user_id']?.toString() ?? '-',
        mappedAt: DateTime.tryParse(json['mapped_at']?.toString() ?? '') ?? DateTime.now(),
        issueDetails: json['issue_details']?.toString() ?? 'Review details unavailable.',
        priority: json['priority']?.toString() ?? 'Normal',
        evidenceLabel: json['evidence_label']?.toString() ?? 'Evidence pending',
      );
}
