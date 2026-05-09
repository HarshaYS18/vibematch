import 'package:flutter/material.dart';

enum ControlCenterSection {
  overview('Command', Icons.dashboard_customize_rounded),
  performance('Performance', Icons.insights_rounded),
  invisibility('Stealth', Icons.visibility_off_rounded),
  logs('Logs', Icons.manage_search_rounded),
  powers('Powers', Icons.admin_panel_settings_rounded),
  bans('Authority', Icons.gavel_rounded),
  review('Review', Icons.fact_check_rounded),
  economy('Coins', Icons.monetization_on_rounded),
  identity('Identity', Icons.badge_rounded);

  const ControlCenterSection(this.label, this.icon);
  final String label;
  final IconData icon;
}

enum PowerCategory {
  moderation('Moderation', Icons.gavel_rounded),
  roles('Roles', Icons.verified_user_rounded),
  economy('Economy', Icons.account_balance_wallet_rounded),
  rooms('Rooms', Icons.meeting_room_rounded),
  reviews('Reviews', Icons.fact_check_rounded),
  identity('Identity', Icons.badge_rounded),
  agency('Agency', Icons.groups_rounded);

  const PowerCategory(this.label, this.icon);
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

const Map<String, int> controlCenterRolePower = {
  'founder_owner': 100,
  'owner': 90,
  'superadmin': 80,
  'admin': 70,
  'monitor': 60,
  'agency_owner': 50,
  'bd': 45,
  'coin_seller': 40,
  'merchant': 40,
  'reseller': 35,
  'cs': 30,
  'user': 10,
};

const Map<PowerCategory, List<String>> controlCenterAuthorityGroups = {
  PowerCategory.moderation: [
    'BAN_USER',
    'UNBAN_USER',
    'TEMP_BAN_USER',
    'PERMANENT_BAN_USER',
    'DEVICE_BAN',
    'DEVICE_UNBAN_FOUNDER_ONLY',
  ],
  PowerCategory.roles: [
    'ASSIGN_ROLE',
    'REMOVE_ROLE',
    'REVOKE_ROLE',
    'VIEW_ADMIN_USERS',
  ],
  PowerCategory.economy: [
    'SEND_COINS',
    'MINT_AUTHORITY_POOL',
    'REMOVE_AUTHORITY_POOL',
    'VIEW_WALLET_LOGS',
  ],
  PowerCategory.rooms: [
    'MANAGE_ROOMS',
    'ROOM_STEALTH_ENTRY',
    'ROOM_KICK',
    'ROOM_MUTE',
    'SECRET_VIBE_ACCESS',
  ],
  PowerCategory.reviews: [
    'REVIEW_REPORTS',
    'APPROVE_ASSETS',
    'REJECT_ASSETS',
    'REVIEW_DP',
    'REVIEW_PAYOUTS',
  ],
  PowerCategory.identity: [
    'ASSIGN_CUSTOM_ID',
    'RESERVE_OFFICIAL_HANDLE',
    'VERIFY_PROFILE',
  ],
  PowerCategory.agency: [
    'MANAGE_AGENCIES',
    'CLOSE_AGENCY',
    'VIEW_HOST_REPORTS',
  ],
};

List<String> get controlCenterAuthorities => controlCenterAuthorityGroups.values.expand((items) => items).toSet().toList();

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
    required this.roleAssignments,
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
  final List<RoleAssignmentEntry> roleAssignments;

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
    List<RoleAssignmentEntry>? roleAssignments,
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
      roleAssignments: roleAssignments ?? this.roleAssignments,
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

class RoleAssignmentEntry {
  const RoleAssignmentEntry({
    required this.id,
    required this.userId,
    required this.role,
    required this.assignedByUserId,
    required this.reason,
    required this.isActive,
    required this.createdAt,
    this.removedAt,
  });

  final String id;
  final String userId;
  final String role;
  final String assignedByUserId;
  final String reason;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? removedAt;

  RoleAssignmentEntry copyWith({bool? isActive, DateTime? removedAt}) => RoleAssignmentEntry(
        id: id,
        userId: userId,
        role: role,
        assignedByUserId: assignedByUserId,
        reason: reason,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        removedAt: removedAt ?? this.removedAt,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'user_id': userId,
        'role': role,
        'assigned_by_user_id': assignedByUserId,
        'reason': reason,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        if (removedAt != null) 'removed_at': removedAt!.toIso8601String(),
      };

  factory RoleAssignmentEntry.fromJson(Map<String, dynamic> json) {
    return RoleAssignmentEntry(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      role: json['role']?.toString() ?? 'user',
      assignedByUserId: json['assigned_by_user_id']?.toString() ?? '6922022',
      reason: json['reason']?.toString() ?? '',
      isActive: json['is_active'] != false,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      removedAt: DateTime.tryParse(json['removed_at']?.toString() ?? ''),
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
    required this.mappedOfficialRole,
    required this.mappedOfficialName,
    required this.mappedOfficialUserId,
    required this.mappedAt,
    required this.issueDetails,
    required this.priority,
    required this.evidenceLabel,
  });

  final String id;
  final String type;
  final String title;
  final String userId;
  final String roomId;
  final String status;
  final DateTime createdAt;
  final String mappedOfficialRole;
  final String mappedOfficialName;
  final String mappedOfficialUserId;
  final DateTime mappedAt;
  final String issueDetails;
  final String priority;
  final String evidenceLabel;

  ReviewQueueItem copyWith({String? status}) => ReviewQueueItem(
        id: id,
        type: type,
        title: title,
        userId: userId,
        roomId: roomId,
        status: status ?? this.status,
        createdAt: createdAt,
        mappedOfficialRole: mappedOfficialRole,
        mappedOfficialName: mappedOfficialName,
        mappedOfficialUserId: mappedOfficialUserId,
        mappedAt: mappedAt,
        issueDetails: issueDetails,
        priority: priority,
        evidenceLabel: evidenceLabel,
      );
}
