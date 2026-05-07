import 'package:flutter/material.dart';

enum ControlCenterSection {
  overview('Overview', Icons.dashboard_rounded),
  invisibility('Invisibility', Icons.visibility_off_rounded),
  logs('Logs', Icons.manage_search_rounded),
  powers('Power Provider', Icons.admin_panel_settings_rounded),
  bans('Ban & Unban', Icons.gavel_rounded),
  review('Review Panel', Icons.fact_check_rounded),
  economy('Coins', Icons.monetization_on_rounded),
  identity('Custom ID', Icons.badge_rounded);

  const ControlCenterSection(this.label, this.icon);
  final String label;
  final IconData icon;
}

const List<String> controlCenterRoles = [
  'owner',
  'superadmin',
  'admin',
  'monitor',
  'cs',
  'agency_owner',
  'bd',
  'coin_seller',
  'merchant',
  'reseller',
  'user',
];

const List<String> controlCenterAuthorities = [
  'ASSIGN_ROLE',
  'REVOKE_ROLE',
  'BAN_USER',
  'UNBAN_USER',
  'TEMP_BAN_USER',
  'PERMANENT_BAN_USER',
  'SEND_COINS',
  'ASSIGN_CUSTOM_ID',
  'REVIEW_REPORTS',
  'APPROVE_ASSETS',
  'MANAGE_ROOMS',
  'MANAGE_AGENCIES',
];

class ControlCenterState {
  const ControlCenterState({
    required this.globalInvisible,
    required this.hideFromOnlineCount,
    required this.hideWhenSeated,
    required this.hideRoomEntryEvents,
    required this.auditInvisibleAccess,
    required this.coinAuthorityBalance,
    required this.logs,
    required this.powerGrants,
    required this.reviewItems,
  });

  final bool globalInvisible;
  final bool hideFromOnlineCount;
  final bool hideWhenSeated;
  final bool hideRoomEntryEvents;
  final bool auditInvisibleAccess;
  final int coinAuthorityBalance;
  final List<ControlLogEntry> logs;
  final List<PowerGrantEntry> powerGrants;
  final List<ReviewQueueItem> reviewItems;

  ControlCenterState copyWith({
    bool? globalInvisible,
    bool? hideFromOnlineCount,
    bool? hideWhenSeated,
    bool? hideRoomEntryEvents,
    bool? auditInvisibleAccess,
    int? coinAuthorityBalance,
    List<ControlLogEntry>? logs,
    List<PowerGrantEntry>? powerGrants,
    List<ReviewQueueItem>? reviewItems,
  }) {
    return ControlCenterState(
      globalInvisible: globalInvisible ?? this.globalInvisible,
      hideFromOnlineCount: hideFromOnlineCount ?? this.hideFromOnlineCount,
      hideWhenSeated: hideWhenSeated ?? this.hideWhenSeated,
      hideRoomEntryEvents: hideRoomEntryEvents ?? this.hideRoomEntryEvents,
      auditInvisibleAccess: auditInvisibleAccess ?? this.auditInvisibleAccess,
      coinAuthorityBalance: coinAuthorityBalance ?? this.coinAuthorityBalance,
      logs: logs ?? this.logs,
      powerGrants: powerGrants ?? this.powerGrants,
      reviewItems: reviewItems ?? this.reviewItems,
    );
  }
}

class ControlLogEntry {
  const ControlLogEntry({
    required this.id,
    required this.actorUserId,
    required this.targetUserId,
    required this.chatRoomId,
    required this.action,
    required this.resourceType,
    required this.reason,
    required this.createdAt,
  });

  final String id;
  final String actorUserId;
  final String targetUserId;
  final String chatRoomId;
  final String action;
  final String resourceType;
  final String reason;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'actor_user_id': actorUserId,
        'target_user_id': targetUserId,
        'chat_room_id': chatRoomId,
        'action': action,
        'resource_type': resourceType,
        'reason': reason,
        'created_at': createdAt.toIso8601String(),
      };

  factory ControlLogEntry.fromJson(Map<String, dynamic> json) {
    return ControlLogEntry(
      id: json['id']?.toString() ?? '',
      actorUserId: json['actor_user_id']?.toString() ?? '',
      targetUserId: json['target_user_id']?.toString() ?? '',
      chatRoomId: json['chat_room_id']?.toString() ?? '',
      action: json['action']?.toString() ?? 'UNKNOWN',
      resourceType: json['resource_type']?.toString() ?? 'system',
      reason: json['reason']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class PowerGrantEntry {
  const PowerGrantEntry({
    required this.id,
    required this.userId,
    required this.role,
    required this.authorities,
    required this.reason,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String role;
  final List<String> authorities;
  final String reason;
  final bool isActive;
  final DateTime createdAt;

  PowerGrantEntry copyWith({bool? isActive}) => PowerGrantEntry(
        id: id,
        userId: userId,
        role: role,
        authorities: authorities,
        reason: reason,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'user_id': userId,
        'role': role,
        'authorities': authorities,
        'reason': reason,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
      };

  factory PowerGrantEntry.fromJson(Map<String, dynamic> json) {
    return PowerGrantEntry(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      role: json['role']?.toString() ?? 'user',
      authorities: (json['authorities'] as List? ?? const <dynamic>[]).map((item) => item.toString()).toList(),
      reason: json['reason']?.toString() ?? '',
      isActive: json['is_active'] != false,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class ReviewQueueItem {
  const ReviewQueueItem({
    required this.id,
    required this.type,
    required this.title,
    required this.userId,
    required this.roomId,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String userId;
  final String roomId;
  final String status;
  final DateTime createdAt;

  ReviewQueueItem copyWith({String? status}) => ReviewQueueItem(
        id: id,
        type: type,
        title: title,
        userId: userId,
        roomId: roomId,
        status: status ?? this.status,
        createdAt: createdAt,
      );
}
