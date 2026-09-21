import '../../../core/network/api_client.dart';
import '../../auth/data/auth_api_service.dart';

class ControlCenterApiService {
  ControlCenterApiService({
    ApiClient? apiClient,
    AuthApiService? authApiService,
  }) : _apiClient = apiClient ?? ApiClient(),
       _authApiService = authApiService ?? const AuthApiService();

  final ApiClient _apiClient;
  final AuthApiService _authApiService;

  Future<AdminControlSummary> loadSummary() async {
    final json = await _apiClient.getMap(
      '/admin/control-summary',
      headers: _headers(),
    );
    return AdminControlSummary.fromJson(json);
  }

  Future<List<AdminUser>> loadUsers() async {
    final json = await _apiClient.getList('/admin/users', headers: _headers());
    return json
        .whereType<Map<String, dynamic>>()
        .map(AdminUser.fromJson)
        .toList(growable: false);
  }

  Future<List<RoleOption>> loadRoleOptions() async {
    final json = await _apiClient.getList(
      '/admin/role-options',
      headers: _headers(),
    );
    return json
        .whereType<Map<String, dynamic>>()
        .map(RoleOption.fromJson)
        .toList(growable: false);
  }

  Future<void> assignRole({
    required int targetUserId,
    required String role,
    required String reason,
  }) async {
    await _apiClient.postMap(
      '/admin/roles/assign',
      headers: _headers(),
      body: {'target_user_id': targetUserId, 'role': role, 'reason': reason},
    );
  }

  Future<void> banUser({
    required int targetUserId,
    required String reason,
    String? deviceId,
  }) async {
    await _apiClient.postMap(
      '/admin/moderation/users/ban',
      headers: _headers(),
      body: {
        'target_user_id': targetUserId,
        'reason': reason,
        if (deviceId != null && deviceId.trim().isNotEmpty)
          'device_id': deviceId.trim(),
      },
    );
  }

  Future<void> unbanUser({
    required int targetUserId,
    required String reason,
  }) async {
    await _apiClient.postMap(
      '/admin/moderation/users/unban',
      headers: _headers(),
      body: {'target_user_id': targetUserId, 'reason': reason},
    );
  }

  Future<List<UserBanItem>> loadUserBans() async {
    final json = await _apiClient.getList(
      '/admin/moderation/users/bans',
      headers: _headers(),
    );
    return json
        .whereType<Map<String, dynamic>>()
        .map(UserBanItem.fromJson)
        .toList(growable: false);
  }

  Future<List<DeviceBanItem>> loadDeviceBans() async {
    final json = await _apiClient.getList(
      '/admin/moderation/devices/bans',
      headers: _headers(),
    );
    return json
        .whereType<Map<String, dynamic>>()
        .map(DeviceBanItem.fromJson)
        .toList(growable: false);
  }

  Future<void> unbanDevice({
    required String deviceId,
    required String reason,
  }) async {
    await _apiClient.postMap(
      '/admin/moderation/devices/unban',
      headers: _headers(),
      body: {'device_id': deviceId, 'reason': reason},
    );
  }

  Future<List<SuperOwnerPoolItem>> loadCoinPools() async {
    final json = await _apiClient.getList(
      '/admin/economy/coin-pools',
      headers: _headers(),
    );
    return json
        .whereType<Map<String, dynamic>>()
        .map(SuperOwnerPoolItem.fromJson)
        .toList(growable: false);
  }

  Future<void> mintCoins({
    required String poolType,
    required int amount,
    required String reason,
    int? targetUserId,
  }) async {
    await _apiClient.postMap(
      '/admin/economy/coins/mint',
      headers: _headers(),
      body: {
        'target_pool_type': poolType,
        'amount': amount,
        'reason': reason,
        'target_user_id': ?targetUserId,
      },
    );
  }

  Future<void> sendCoinsToAll({
    required int coinAmount,
    required bool activeOnly,
    required String reason,
  }) async {
    await _apiClient.postMap(
      '/admin/economy/coins/send-all',
      headers: _headers(),
      body: {
        'coin_amount': coinAmount,
        'active_only': activeOnly,
        'reason': reason,
      },
    );
  }

  Future<void> assignCustomId({
    required int targetUserId,
    required int? customId,
    required String reason,
  }) async {
    await _apiClient.postMap(
      '/admin/users/custom-id',
      headers: _headers(),
      body: {
        'target_user_id': targetUserId,
        'display_custom_id': customId,
        'reason': reason,
      },
    );
  }

  Future<void> setStealth({
    required int targetUserId,
    required bool enabled,
    required String reason,
  }) async {
    await _apiClient.postMap(
      '/admin/users/stealth',
      headers: _headers(),
      body: {
        'target_user_id': targetUserId,
        'enabled': enabled,
        'reason': reason,
      },
    );
  }

  Future<List<SpecialPermissionOption>> loadSpecialPermissionOptions() async {
    final json = await _apiClient.getList(
      '/admin/users/special-permissions/options',
      headers: _headers(),
    );
    return json
        .whereType<Map<String, dynamic>>()
        .map(SpecialPermissionOption.fromJson)
        .toList(growable: false);
  }

  Future<void> grantSpecialPermission({
    required int targetUserId,
    required String permission,
    required String reason,
  }) async {
    await _apiClient.postMap(
      '/admin/users/special-permissions/grant',
      headers: _headers(),
      body: {
        'target_user_id': targetUserId,
        'permission': permission,
        'reason': reason,
      },
    );
  }

  Future<void> adjustVip({
    required int targetUserId,
    required int vipLevel,
    required int svipLevel,
    required bool vipActive,
    required bool svipActive,
    required String reason,
  }) async {
    await _apiClient.postMap(
      '/admin/users/vip-adjust',
      headers: _headers(),
      body: {
        'target_user_id': targetUserId,
        'vip_level': vipLevel,
        'svip_level': svipLevel,
        'vip_is_active': vipActive,
        'svip_is_active': svipActive,
        'reason': reason,
      },
    );
  }

  Future<void> adjustLevels({
    required int targetUserId,
    int? sendExpTotal,
    int? receiveExpTotal,
    int? rubyTotal,
    required String reason,
  }) async {
    await _apiClient.postMap(
      '/admin/users/levels-adjust',
      headers: _headers(),
      body: {
        'target_user_id': targetUserId,
        'send_exp_total': ?sendExpTotal,
        'receive_exp_total': ?receiveExpTotal,
        'ruby_total': ?rubyTotal,
        'reason': reason,
      },
    );
  }

  Future<List<SuperOwnerLogItem>> loadSuperOwnerLogs() async {
    final json = await _apiClient.getList(
      '/admin/moderation/owner-logs',
      headers: _headers(),
    );
    return json
        .whereType<Map<String, dynamic>>()
        .map(SuperOwnerLogItem.fromJson)
        .toList(growable: false);
  }

  Future<List<SuperOwnerReviewItem>> loadReviewItems() async {
    final json = await _apiClient.getList(
      '/admin/moderation/reviews',
      headers: _headers(),
    );
    return json
        .whereType<Map<String, dynamic>>()
        .map(SuperOwnerReviewItem.fromJson)
        .toList(growable: false);
  }

  Future<SuperOwnerReviewItem> loadReviewDetail(int reviewId) async {
    final json = await _apiClient.getMap(
      '/admin/moderation/reviews/$reviewId',
      headers: _headers(),
    );
    return SuperOwnerReviewItem.fromJson(json);
  }

  Future<List<ControlCenterEconomyRuleSet>> loadEconomyRuleSets() async {
    final json = await _apiClient.getList(
      '/admin/economy/rules',
      headers: _headers(),
    );
    return json
        .whereType<Map<String, dynamic>>()
        .map(ControlCenterEconomyRuleSet.fromJson)
        .toList(growable: false);
  }

  Future<void> updateEconomyRuleSet({
    required String trackKey,
    required String title,
    required List<Map<String, dynamic>> levels,
    required String reason,
  }) async {
    await _apiClient.postMap(
      '/admin/economy/rules/$trackKey',
      headers: _headers(),
      body: {'title': title, 'levels': levels, 'reason': reason},
    );
  }

  Future<List<ControlCenterStoreCategory>> loadStoreCategories() async {
    final json = await _apiClient.getList(
      '/admin/economy/store/categories',
      headers: _headers(),
    );
    return json
        .whereType<Map<String, dynamic>>()
        .map(ControlCenterStoreCategory.fromJson)
        .toList(growable: false);
  }

  Future<List<ControlCenterStoreItem>> loadStoreItems({
    String? category,
  }) async {
    final json = await _apiClient.getList(
      '/admin/economy/store/items',
      headers: _headers(),
      queryParameters: {'category': category},
    );
    return json
        .whereType<Map<String, dynamic>>()
        .map(ControlCenterStoreItem.fromJson)
        .toList(growable: false);
  }

  Future<void> upsertStoreCategory(Map<String, dynamic> payload) async {
    await _apiClient.postMap(
      '/admin/economy/store/categories',
      headers: _headers(),
      body: payload,
    );
  }

  Future<void> upsertStoreItem(Map<String, dynamic> payload) async {
    await _apiClient.postMap(
      '/admin/economy/store/items',
      headers: _headers(),
      body: payload,
    );
  }

  Future<Map<String, dynamic>> previewStoreManifest(
    Map<String, dynamic> manifest,
  ) {
    return _apiClient.postMap(
      '/admin/economy/store/manifest/preview',
      headers: _headers(),
      body: {'manifest': manifest},
    );
  }

  Future<Map<String, dynamic>> importStoreManifest({
    required Map<String, dynamic> manifest,
    required String reason,
  }) {
    return _apiClient.postMap(
      '/admin/economy/store/manifest/import',
      headers: _headers(),
      body: {'manifest': manifest, 'reason': reason},
    );
  }

  Future<StealthState> loadMyStealthState() async {
    final json = await _apiClient.getMap(
      '/users/me/stealth',
      headers: _headers(),
    );
    return StealthState.fromJson(json);
  }

  Future<StealthState> toggleMyStealth({
    required bool enabled,
    required String reason,
  }) async {
    final json = await _apiClient.postMap(
      '/users/me/stealth',
      headers: _headers(),
      body: {'enabled': enabled, 'reason': reason},
    );
    return StealthState.fromJson(json);
  }

  Future<StealthState> grantStealth({
    required int targetUserId,
    required bool enabled,
    required String reason,
  }) async {
    final json = await _apiClient.postMap(
      '/admin/users/stealth/grants',
      headers: _headers(),
      body: {
        'target_user_id': targetUserId,
        'enabled': enabled,
        'reason': reason,
      },
    );
    return StealthState.fromJson(json);
  }

  Map<String, String> _headers() {
    final token = _authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Please login again before opening Control Center.');
    }
    return {'Authorization': 'Bearer $token'};
  }

  void close() => _apiClient.close();
}

class AdminControlSummary {
  const AdminControlSummary({
    required this.currentUserId,
    required this.currentPrimaryRole,
    required this.canAssignRoles,
    required this.canViewAuditLogs,
    required this.canViewLoginHistory,
    required this.usersCount,
    required this.activeUsersCount,
    required this.bannedUsersCount,
    required this.officialUsersCount,
    required this.recentAuditCount,
  });
  final int currentUserId;
  final String currentPrimaryRole;
  final bool canAssignRoles;
  final bool canViewAuditLogs;
  final bool canViewLoginHistory;
  final int usersCount;
  final int activeUsersCount;
  final int bannedUsersCount;
  final int officialUsersCount;
  final int recentAuditCount;
  bool get isSuperOwnerPanel => currentPrimaryRole == 'founder_owner';
  bool get isOwnerPanel => currentPrimaryRole == 'owner';
  bool get isSuperAdminPanel => currentPrimaryRole == 'superadmin';
  factory AdminControlSummary.fromJson(Map<String, dynamic> json) =>
      AdminControlSummary(
        currentUserId: _int(json['current_user_id']),
        currentPrimaryRole: json['current_primary_role']?.toString() ?? 'user',
        canAssignRoles: json['can_assign_roles'] == true,
        canViewAuditLogs: json['can_view_audit_logs'] == true,
        canViewLoginHistory: json['can_view_login_history'] == true,
        usersCount: _int(json['users_count']),
        activeUsersCount: _int(json['active_users_count']),
        bannedUsersCount: _int(json['banned_users_count']),
        officialUsersCount: _int(json['official_users_count']),
        recentAuditCount: _int(json['recent_audit_count']),
      );
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.publicUserId,
    required this.displayName,
    required this.username,
    required this.isActive,
    required this.isBanned,
    required this.roles,
    required this.primaryRole,
    this.displayCustomId,
  });
  final int id;
  final int publicUserId;
  final int? displayCustomId;
  final String displayName;
  final String username;
  final bool isActive;
  final bool isBanned;
  final List<String> roles;
  final String primaryRole;
  String get title => displayName.trim().isNotEmpty ? displayName : username;
  String get roleLabel => primaryRole.replaceAll('_', ' ').toUpperCase();
  bool get isNormalUser => primaryRole == 'user';
  factory AdminUser.fromJson(Map<String, dynamic> json) {
    final username =
        json['username']?.toString() ?? 'user_${json['public_user_id']}';
    final displayName = json['display_name']?.toString() ?? username;
    final rolesRaw = json['roles'];
    return AdminUser(
      id: _int(json['id']),
      publicUserId: _int(json['public_user_id']),
      displayCustomId: json['display_custom_id'] == null
          ? null
          : _int(json['display_custom_id']),
      displayName: displayName,
      username: username,
      isActive: json['is_active'] != false,
      isBanned: json['is_banned'] == true,
      roles: rolesRaw is List
          ? rolesRaw.map((item) => item.toString()).toList(growable: false)
          : const <String>[],
      primaryRole: json['primary_role']?.toString() ?? 'user',
    );
  }
}

class RoleOption {
  const RoleOption({
    required this.value,
    required this.label,
    required this.power,
    required this.assignable,
  });
  final String value;
  final String label;
  final int power;
  final bool assignable;
  factory RoleOption.fromJson(Map<String, dynamic> json) => RoleOption(
    value: json['value']?.toString() ?? 'user',
    label: json['label']?.toString() ?? 'User',
    power: _int(json['power']),
    assignable: json['assignable'] == true,
  );
}

class UserBanItem {
  const UserBanItem({
    required this.id,
    required this.userId,
    required this.reason,
    required this.isActive,
    this.deviceId,
  });
  final int id;
  final int userId;
  final String reason;
  final bool isActive;
  final String? deviceId;
  factory UserBanItem.fromJson(Map<String, dynamic> json) => UserBanItem(
    id: _int(json['id']),
    userId: _int(json['user_id']),
    reason: json['reason']?.toString() ?? 'No reason',
    isActive: json['is_active'] != false,
    deviceId: json['device_id_snapshot']?.toString(),
  );
}

class DeviceBanItem {
  const DeviceBanItem({
    required this.id,
    required this.deviceId,
    required this.reason,
    required this.isActive,
  });
  final int id;
  final String deviceId;
  final String reason;
  final bool isActive;
  factory DeviceBanItem.fromJson(Map<String, dynamic> json) => DeviceBanItem(
    id: _int(json['id']),
    deviceId: json['device_id']?.toString() ?? '',
    reason: json['reason']?.toString() ?? 'No reason',
    isActive: json['is_active'] != false,
  );
}

class SuperOwnerPoolItem {
  const SuperOwnerPoolItem({
    required this.id,
    required this.ownerUserId,
    required this.poolType,
    required this.balance,
    required this.reservedBalance,
    required this.status,
  });
  final int id;
  final int? ownerUserId;
  final String poolType;
  final int balance;
  final int reservedBalance;
  final String status;
  factory SuperOwnerPoolItem.fromJson(Map<String, dynamic> json) =>
      SuperOwnerPoolItem(
        id: _int(json['id']),
        ownerUserId: json['owner_user_id'] == null
            ? null
            : _int(json['owner_user_id']),
        poolType: json['pool_type']?.toString() ?? '',
        balance: _int(json['balance']),
        reservedBalance: _int(json['reserved_balance']),
        status: json['status']?.toString() ?? 'ACTIVE',
      );
}

class SpecialPermissionOption {
  const SpecialPermissionOption({required this.value, required this.label});
  final String value;
  final String label;
  factory SpecialPermissionOption.fromJson(Map<String, dynamic> json) =>
      SpecialPermissionOption(
        value: json['value']?.toString() ?? '',
        label: json['label']?.toString() ?? 'Permission',
      );
}

class SuperOwnerLogItem {
  const SuperOwnerLogItem({
    required this.id,
    required this.action,
    required this.reason,
    required this.createdAt,
    this.actorUserId,
    this.targetUserId,
    this.resourceType,
  });
  final int id;
  final int? actorUserId;
  final int? targetUserId;
  final String action;
  final String? resourceType;
  final String reason;
  final String createdAt;
  factory SuperOwnerLogItem.fromJson(Map<String, dynamic> json) =>
      SuperOwnerLogItem(
        id: _int(json['id']),
        actorUserId: json['actor_user_id'] == null
            ? null
            : _int(json['actor_user_id']),
        targetUserId: json['target_user_id'] == null
            ? null
            : _int(json['target_user_id']),
        action: json['action']?.toString() ?? 'LOG',
        resourceType: json['resource_type']?.toString(),
        reason: json['reason']?.toString() ?? '',
        createdAt: json['created_at']?.toString() ?? '',
      );
}

class SuperOwnerReviewItem {
  const SuperOwnerReviewItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.status,
    required this.reason,
    required this.createdAt,
  });
  final int id;
  final String kind;
  final String title;
  final String status;
  final String reason;
  final String createdAt;
  factory SuperOwnerReviewItem.fromJson(Map<String, dynamic> json) =>
      SuperOwnerReviewItem(
        id: _int(json['id']),
        kind: json['kind']?.toString() ?? 'audit',
        title: json['title']?.toString() ?? 'Review',
        status: json['status']?.toString() ?? 'open',
        reason: json['reason']?.toString() ?? '',
        createdAt: json['created_at']?.toString() ?? '',
      );
}

class ControlCenterEconomyRuleSet {
  const ControlCenterEconomyRuleSet({
    required this.id,
    required this.trackKey,
    required this.version,
    required this.title,
    required this.maxLevel,
    required this.levelCount,
    required this.levels,
  });
  final int id;
  final String trackKey;
  final int version;
  final String title;
  final int maxLevel;
  final int levelCount;
  final List<ControlCenterEconomyRuleLevel> levels;
  factory ControlCenterEconomyRuleSet.fromJson(Map<String, dynamic> json) {
    final levels = json['levels'];
    final parsedLevels = levels is List
        ? levels
              .whereType<Map<String, dynamic>>()
              .map(ControlCenterEconomyRuleLevel.fromJson)
              .toList(growable: false)
        : const <ControlCenterEconomyRuleLevel>[];
    return ControlCenterEconomyRuleSet(
      id: _int(json['id']),
      trackKey: json['track_key']?.toString() ?? '',
      version: _int(json['version']),
      title: json['title']?.toString() ?? '',
      maxLevel: _int(json['max_level']),
      levelCount: parsedLevels.length,
      levels: parsedLevels,
    );
  }
}

class ControlCenterEconomyRuleLevel {
  const ControlCenterEconomyRuleLevel({
    required this.level,
    required this.requiredExp,
    required this.requiredCoinValue,
  });

  final int level;
  final int requiredExp;
  final int requiredCoinValue;

  factory ControlCenterEconomyRuleLevel.fromJson(Map<String, dynamic> json) =>
      ControlCenterEconomyRuleLevel(
        level: _int(json['level']),
        requiredExp: _int(json['required_exp']),
        requiredCoinValue: _int(json['required_coin_value']),
      );

  Map<String, dynamic> toRuleJson({int? requiredCoins}) => {
    'level': level,
    'required_exp': requiredCoins ?? requiredExp,
    'required_coin_value': requiredCoins ?? requiredCoinValue,
  };
}

class ControlCenterStoreCategory {
  const ControlCenterStoreCategory({
    required this.key,
    required this.label,
    required this.active,
    required this.sortOrder,
  });
  final String key;
  final String label;
  final bool active;
  final int sortOrder;
  factory ControlCenterStoreCategory.fromJson(Map<String, dynamic> json) =>
      ControlCenterStoreCategory(
        key: json['category_key']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        active: json['is_active'] != false,
        sortOrder: _int(json['sort_order']),
      );
}

class ControlCenterStoreItem {
  const ControlCenterStoreItem({
    required this.itemId,
    required this.name,
    required this.category,
    required this.itemType,
    required this.priceCoins,
    required this.active,
    required this.sortOrder,
    this.assetUrl,
    this.thumbnailUrl,
    this.imageUrl,
  });
  final String itemId;
  final String name;
  final String category;
  final String itemType;
  final int priceCoins;
  final bool active;
  final int sortOrder;
  final String? assetUrl;
  final String? thumbnailUrl;
  final String? imageUrl;

  String get displayAssetUrl {
    final primary = assetUrl?.trim();
    if (primary != null && primary.isNotEmpty) return primary;
    final image = imageUrl?.trim();
    if (image != null && image.isNotEmpty) return image;
    final thumb = thumbnailUrl?.trim();
    if (thumb != null && thumb.isNotEmpty) return thumb;
    return '';
  }

  factory ControlCenterStoreItem.fromJson(Map<String, dynamic> json) =>
      ControlCenterStoreItem(
        itemId: json['item_id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        category: json['category']?.toString() ?? '',
        itemType: json['item_type']?.toString() ?? '',
        priceCoins: _int(json['price_coins']),
        active: json['is_active'] != false,
        sortOrder: _int(json['sort_order']),
        assetUrl: _text(json['cdn_asset_url']),
        thumbnailUrl: _text(json['thumbnail_url']),
        imageUrl: _text(json['image_url']),
      );
}

class StealthState {
  const StealthState({
    required this.userId,
    required this.enabled,
    required this.canUseStealth,
  });
  final int userId;
  final bool enabled;
  final bool canUseStealth;
  factory StealthState.fromJson(Map<String, dynamic> json) => StealthState(
    userId: _int(json['user_id']),
    enabled: json['is_enabled'] == true,
    canUseStealth: json['can_use_stealth'] == true,
  );
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String? _text(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty || text == 'null') return null;
  return text;
}
