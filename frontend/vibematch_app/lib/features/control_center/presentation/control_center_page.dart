import 'package:flutter/material.dart';

import '../data/control_center_api_service.dart';

class ControlCenterPage extends StatefulWidget {
  const ControlCenterPage({super.key});

  @override
  State<ControlCenterPage> createState() => _ControlCenterPageState();
}

class _ControlCenterPageState extends State<ControlCenterPage> {
  final ControlCenterApiService _api = ControlCenterApiService();

  AdminControlSummary? _summary;
  List<AdminUser> _users = const <AdminUser>[];
  List<RoleOption> _roles = const <RoleOption>[];
  List<UserBanItem> _userBans = const <UserBanItem>[];
  List<DeviceBanItem> _deviceBans = const <DeviceBanItem>[];
  List<SuperOwnerPoolItem> _coinPools = const <SuperOwnerPoolItem>[];
  List<SpecialPermissionOption> _permissionOptions = const <SpecialPermissionOption>[];
  List<SuperOwnerLogItem> _logs = const <SuperOwnerLogItem>[];
  List<SuperOwnerReviewItem> _reviews = const <SuperOwnerReviewItem>[];

  bool _loading = true;
  bool _busy = false;
  String? _error;

  bool get _isSuperOwner => _summary?.isSuperOwnerPanel == true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await _api.loadSummary();
      final users = await _api.loadUsers();
      final roles = await _api.loadRoleOptions();
      var userBans = const <UserBanItem>[];
      var deviceBans = const <DeviceBanItem>[];
      var pools = const <SuperOwnerPoolItem>[];
      var permissions = const <SpecialPermissionOption>[];
      var logs = const <SuperOwnerLogItem>[];
      var reviews = const <SuperOwnerReviewItem>[];
      try {
        userBans = await _api.loadUserBans();
      } catch (_) {}
      if (summary.isSuperOwnerPanel) {
        try {
          deviceBans = await _api.loadDeviceBans();
        } catch (_) {}
        try {
          pools = await _api.loadCoinPools();
        } catch (_) {}
        try {
          permissions = await _api.loadSpecialPermissionOptions();
        } catch (_) {}
        try {
          logs = await _api.loadSuperOwnerLogs();
        } catch (_) {}
        try {
          reviews = await _api.loadReviewItems();
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _users = users;
        _roles = roles;
        _userBans = userBans;
        _deviceBans = deviceBans;
        _coinPools = pools;
        _permissionOptions = permissions;
        _logs = logs;
        _reviews = reviews;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _cleanError(error);
      });
    }
  }

  String _cleanError(Object error) => error.toString().replaceFirst('Exception: ', '');

  void _toast(String message, {bool danger = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: danger ? const Color(0xFFE84C72) : const Color(0xFF12C7B7),
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      );
  }

  Future<void> _runAction(Future<void> Function() action, String success) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      _toast(success);
      await _load();
    } catch (error) {
      if (!mounted) return;
      _toast(_cleanError(error), danger: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  AdminUser? _findUserByPublicId(String text) {
    final id = int.tryParse(text.trim());
    if (id == null) return null;
    for (final user in _users) {
      if (user.publicUserId == id || user.id == id) return user;
    }
    return null;
  }

  Future<void> _openAssignRoleSheet(AdminUser user) async {
    final assignableRoles = _roles.where((role) => role.assignable).toList(growable: false);
    if (_summary?.canAssignRoles != true || assignableRoles.isEmpty) {
      _toast('Founder Owner access is required to assign official roles.', danger: true);
      return;
    }
    RoleOption selected = assignableRoles.firstWhere((role) => role.value == user.primaryRole, orElse: () => assignableRoles.first);
    final reason = TextEditingController(text: 'Super Owner role update');
    await _showControlSheet(
      title: 'Assign role',
      subtitle: '${user.title} • ID ${user.publicUserId}',
      childBuilder: (setSheetState) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<RoleOption>(
            initialValue: selected,
            decoration: _input('Role'),
            items: assignableRoles.map((role) => DropdownMenuItem(value: role, child: Text('${role.label} • P${role.power}'))).toList(growable: false),
            onChanged: (role) {
              if (role != null) setSheetState(() => selected = role);
            },
          ),
          const SizedBox(height: 12),
          _ReasonField(controller: reason),
          const SizedBox(height: 14),
          _PrimaryActionButton(
            busy: _busy,
            label: 'Assign role',
            busyLabel: 'Assigning...',
            icon: Icons.manage_accounts_rounded,
            onPressed: () {
              final safeReason = reason.text.trim();
              if (safeReason.isEmpty) return _toast('Reason is required.', danger: true);
              Navigator.pop(context);
              _runAction(() => _api.assignRole(targetUserId: user.id, role: selected.value, reason: safeReason), 'Role updated and audit logged.');
            },
          ),
        ],
      ),
    );
    reason.dispose();
  }

  Future<void> _openBanSheet(AdminUser user) async {
    if (!user.isNormalUser) {
      _toast('Protected/official users cannot be moderated from this normal-user action.', danger: true);
      return;
    }
    final reason = TextEditingController(text: user.isBanned ? 'Super Owner unban review' : 'Super Owner moderation action');
    final deviceId = TextEditingController();
    await _showControlSheet(
      title: user.isBanned ? 'Unban user' : 'Ban user',
      subtitle: '${user.title} • ID ${user.publicUserId}',
      childBuilder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ReasonField(controller: reason),
          if (!user.isBanned) ...[
            const SizedBox(height: 12),
            TextField(controller: deviceId, decoration: _input('Device ID snapshot optional')),
          ],
          const SizedBox(height: 14),
          _PrimaryActionButton(
            busy: _busy,
            danger: !user.isBanned,
            label: user.isBanned ? 'Unban' : 'Ban',
            busyLabel: 'Saving...',
            icon: user.isBanned ? Icons.lock_open_rounded : Icons.block_rounded,
            onPressed: () {
              final safeReason = reason.text.trim();
              if (safeReason.isEmpty) return _toast('Reason is required.', danger: true);
              Navigator.pop(context);
              _runAction(
                () => user.isBanned
                    ? _api.unbanUser(targetUserId: user.id, reason: safeReason)
                    : _api.banUser(targetUserId: user.id, reason: safeReason, deviceId: deviceId.text),
                user.isBanned ? 'User unbanned and audit logged.' : 'User banned and audit logged.',
              );
            },
          ),
        ],
      ),
    );
    reason.dispose();
    deviceId.dispose();
  }

  Future<void> _openDeviceUnbanSheet(DeviceBanItem ban) async {
    final reason = TextEditingController(text: 'Founder Owner device unban review');
    await _showControlSheet(
      title: 'Unban device',
      subtitle: ban.deviceId,
      childBuilder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ReasonField(controller: reason),
          const SizedBox(height: 14),
          _PrimaryActionButton(
            busy: _busy,
            label: 'Unban device',
            busyLabel: 'Unbanning...',
            icon: Icons.phonelink_lock_rounded,
            onPressed: () {
              final safeReason = reason.text.trim();
              if (safeReason.isEmpty) return _toast('Reason is required.', danger: true);
              Navigator.pop(context);
              _runAction(() => _api.unbanDevice(deviceId: ban.deviceId, reason: safeReason), 'Device unbanned and audit logged.');
            },
          ),
        ],
      ),
    );
    reason.dispose();
  }

  Future<void> _openMintCoinsSheet() async {
    final amount = TextEditingController();
    final target = TextEditingController();
    final reason = TextEditingController(text: 'Founder Owner supply mint');
    const poolTypes = <String>[
      'FOUNDER_MINT_POOL',
      'OWNER_SUPPLY_POOL',
      'MERCHANT_SUPPLY_POOL',
      'SELLER_SUPPLY_POOL',
      'FRIENDS_GAMING_POOL',
      'EVENT_POOL',
    ];
    var selectedPool = poolTypes.first;
    await _showControlSheet(
      title: 'Mint supply coins',
      subtitle: 'Stored in coin_supply_pools and coin_pool_ledger, not wallet balance.',
      childBuilder: (setSheetState) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: selectedPool,
            decoration: _input('Target pool'),
            items: poolTypes.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(growable: false),
            onChanged: (value) {
              if (value != null) setSheetState(() => selectedPool = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(controller: target, keyboardType: TextInputType.number, decoration: _input('Target internal user ID optional')),
          const SizedBox(height: 12),
          TextField(controller: amount, keyboardType: TextInputType.number, decoration: _input('Coin amount')),
          const SizedBox(height: 12),
          _ReasonField(controller: reason),
          const SizedBox(height: 14),
          _PrimaryActionButton(
            busy: _busy,
            label: 'Mint coins',
            busyLabel: 'Minting...',
            icon: Icons.add_circle_rounded,
            onPressed: () {
              final coinAmount = int.tryParse(amount.text.trim()) ?? 0;
              final targetUserId = int.tryParse(target.text.trim());
              final safeReason = reason.text.trim();
              if (coinAmount <= 0 || safeReason.isEmpty) return _toast('Amount and reason are required.', danger: true);
              Navigator.pop(context);
              _runAction(() => _api.mintCoins(poolType: selectedPool, amount: coinAmount, targetUserId: targetUserId, reason: safeReason), 'Coins minted to supply pool and audit logged.');
            },
          ),
        ],
      ),
    );
    amount.dispose();
    target.dispose();
    reason.dispose();
  }

  Future<void> _openSendAllSheet() async {
    final amount = TextEditingController();
    final reason = TextEditingController(text: 'Founder Owner coin grant to active users');
    var activeOnly = true;
    await _showControlSheet(
      title: 'Send coins to all users',
      subtitle: 'Credits user_wallets and writes wallet_ledger + admin_logs.',
      childBuilder: (setSheetState) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile.adaptive(
            value: activeOnly,
            onChanged: (value) => setSheetState(() => activeOnly = value),
            title: const Text('Active users only', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
          TextField(controller: amount, keyboardType: TextInputType.number, decoration: _input('Coins per user')),
          const SizedBox(height: 12),
          _ReasonField(controller: reason),
          const SizedBox(height: 14),
          _PrimaryActionButton(
            busy: _busy,
            label: 'Send coins',
            busyLabel: 'Sending...',
            icon: Icons.send_rounded,
            onPressed: () {
              final coins = int.tryParse(amount.text.trim()) ?? 0;
              final safeReason = reason.text.trim();
              if (coins <= 0 || safeReason.isEmpty) return _toast('Amount and reason are required.', danger: true);
              Navigator.pop(context);
              _runAction(() => _api.sendCoinsToAll(coinAmount: coins, activeOnly: activeOnly, reason: safeReason), 'Coins sent to users and audit logged.');
            },
          ),
        ],
      ),
    );
    amount.dispose();
    reason.dispose();
  }

  Future<void> _openCustomIdSheet(AdminUser user) async {
    final customId = TextEditingController(text: user.displayCustomId?.toString() ?? '');
    final reason = TextEditingController(text: 'Founder Owner custom ID update');
    await _showControlSheet(
      title: 'Assign custom ID',
      subtitle: '${user.title} • ID ${user.publicUserId}',
      childBuilder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: customId, keyboardType: TextInputType.number, decoration: _input('Custom display ID, empty to clear')),
          const SizedBox(height: 12),
          _ReasonField(controller: reason),
          const SizedBox(height: 14),
          _PrimaryActionButton(
            busy: _busy,
            label: 'Save custom ID',
            busyLabel: 'Saving...',
            icon: Icons.badge_rounded,
            onPressed: () {
              final text = customId.text.trim();
              final parsed = text.isEmpty ? null : int.tryParse(text);
              final safeReason = reason.text.trim();
              if (text.isNotEmpty && parsed == null) return _toast('Custom ID must be numeric.', danger: true);
              if (safeReason.isEmpty) return _toast('Reason is required.', danger: true);
              Navigator.pop(context);
              _runAction(() => _api.assignCustomId(targetUserId: user.id, customId: parsed, reason: safeReason), 'Custom ID updated and audit logged.');
            },
          ),
        ],
      ),
    );
    customId.dispose();
    reason.dispose();
  }

  Future<void> _openVipSheet(AdminUser user) async {
    final vip = TextEditingController(text: '0');
    final svip = TextEditingController(text: '0');
    final reason = TextEditingController(text: 'Founder Owner VIP/SVIP adjustment');
    var vipActive = true;
    var svipActive = false;
    await _showControlSheet(
      title: 'Adjust VIP / SVIP',
      subtitle: '${user.title} • ID ${user.publicUserId}',
      childBuilder: (setSheetState) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Expanded(child: TextField(controller: vip, keyboardType: TextInputType.number, decoration: _input('VIP level'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: svip, keyboardType: TextInputType.number, decoration: _input('SVIP level'))),
          ]),
          SwitchListTile.adaptive(value: vipActive, onChanged: (value) => setSheetState(() => vipActive = value), title: const Text('VIP active')),
          SwitchListTile.adaptive(value: svipActive, onChanged: (value) => setSheetState(() => svipActive = value), title: const Text('SVIP active')),
          _ReasonField(controller: reason),
          const SizedBox(height: 14),
          _PrimaryActionButton(
            busy: _busy,
            label: 'Save VIP/SVIP',
            busyLabel: 'Saving...',
            icon: Icons.workspace_premium_rounded,
            onPressed: () {
              final vipLevel = int.tryParse(vip.text.trim()) ?? -1;
              final svipLevel = int.tryParse(svip.text.trim()) ?? -1;
              final safeReason = reason.text.trim();
              if (vipLevel < 0 || svipLevel < 0 || safeReason.isEmpty) return _toast('Levels and reason are required.', danger: true);
              Navigator.pop(context);
              _runAction(
                () => _api.adjustVip(targetUserId: user.id, vipLevel: vipLevel, svipLevel: svipLevel, vipActive: vipActive, svipActive: svipActive, reason: safeReason),
                'VIP/SVIP stored in DB and audit logged.',
              );
            },
          ),
        ],
      ),
    );
    vip.dispose();
    svip.dispose();
    reason.dispose();
  }

  Future<void> _openGrantPermissionSheet(AdminUser user) async {
    if (_permissionOptions.isEmpty) {
      _toast('No special permissions returned by backend.', danger: true);
      return;
    }
    var selected = _permissionOptions.first;
    final reason = TextEditingController(text: 'Founder Owner special permission grant');
    await _showControlSheet(
      title: 'Grant special permission',
      subtitle: '${user.title} • ID ${user.publicUserId}',
      childBuilder: (setSheetState) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<SpecialPermissionOption>(
            initialValue: selected,
            decoration: _input('Permission'),
            items: _permissionOptions.map((item) => DropdownMenuItem(value: item, child: Text(item.label))).toList(growable: false),
            onChanged: (value) {
              if (value != null) setSheetState(() => selected = value);
            },
          ),
          const SizedBox(height: 12),
          _ReasonField(controller: reason),
          const SizedBox(height: 14),
          _PrimaryActionButton(
            busy: _busy,
            label: 'Grant permission',
            busyLabel: 'Granting...',
            icon: Icons.key_rounded,
            onPressed: () {
              final safeReason = reason.text.trim();
              if (safeReason.isEmpty) return _toast('Reason is required.', danger: true);
              Navigator.pop(context);
              _runAction(() => _api.grantSpecialPermission(targetUserId: user.id, permission: selected.value, reason: safeReason), 'Special permission stored and audit logged.');
            },
          ),
        ],
      ),
    );
    reason.dispose();
  }

  Future<void> _openStealthSheet() async {
    final userId = TextEditingController();
    final reason = TextEditingController(text: 'Founder Owner stealth visibility update');
    var enabled = true;
    await _showControlSheet(
      title: 'Stealth mode',
      subtitle: 'Use internal user ID or public user ID shown in users list.',
      childBuilder: (setSheetState) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: userId, keyboardType: TextInputType.number, decoration: _input('Target user ID / public ID')),
          SwitchListTile.adaptive(value: enabled, onChanged: (value) => setSheetState(() => enabled = value), title: const Text('Enable stealth marker')),
          _ReasonField(controller: reason),
          const SizedBox(height: 14),
          _PrimaryActionButton(
            busy: _busy,
            label: 'Save stealth',
            busyLabel: 'Saving...',
            icon: Icons.visibility_off_rounded,
            onPressed: () {
              final user = _findUserByPublicId(userId.text);
              final safeReason = reason.text.trim();
              if (user == null || safeReason.isEmpty) return _toast('Valid user ID and reason are required.', danger: true);
              Navigator.pop(context);
              _runAction(() => _api.setStealth(targetUserId: user.id, enabled: enabled, reason: safeReason), 'Stealth setting stored and audit logged.');
            },
          ),
        ],
      ),
    );
    userId.dispose();
    reason.dispose();
  }

  InputDecoration _input(String label) => InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)));

  Future<void> _showControlSheet({required String title, required String subtitle, required Widget Function(StateSetter setSheetState) childBuilder}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => _ControlSheet(title: title, subtitle: subtitle, child: childBuilder(setSheetState)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final panelTitle = summary?.isSuperOwnerPanel == true
        ? 'Super Owner Control Panel'
        : summary?.isOwnerPanel == true
            ? 'Owner Control Panel'
            : 'Official Control Center';

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F1),
        foregroundColor: const Color(0xFF251538),
        elevation: 0,
        title: Text(panelTitle, style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF12C7B7)))
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  color: const Color(0xFF12C7B7),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                    children: [
                      if (summary != null) _SummaryCard(summary: summary),
                      const SizedBox(height: 14),
                      if (_isSuperOwner) _SuperOwnerActionsCard(onMint: _openMintCoinsSheet, onSendAll: _openSendAllSheet, onStealth: _openStealthSheet),
                      if (_isSuperOwner) const SizedBox(height: 14),
                      if (_isSuperOwner) _PoolsCard(pools: _coinPools),
                      if (_isSuperOwner) const SizedBox(height: 14),
                      if (_deviceBans.isNotEmpty) ...[
                        _SectionHeader(title: 'Device bans', subtitle: '${_deviceBans.length} records'),
                        const SizedBox(height: 10),
                        ..._deviceBans.map((ban) => _DeviceBanCard(ban: ban, onUnban: () => _openDeviceUnbanSheet(ban))),
                        const SizedBox(height: 14),
                      ],
                      if (_userBans.isNotEmpty) ...[
                        _SectionHeader(title: 'User bans', subtitle: '${_userBans.length} latest'),
                        const SizedBox(height: 10),
                        ..._userBans.take(5).map((ban) => _UserBanCard(ban: ban)),
                        const SizedBox(height: 14),
                      ],
                      _SectionHeader(title: 'Users & controls', subtitle: '${_users.length} shown'),
                      const SizedBox(height: 10),
                      ..._users.map(
                        (user) => _AdminUserCard(
                          user: user,
                          canAssign: summary?.canAssignRoles == true,
                          canModerate: summary != null && (summary.isSuperOwnerPanel || summary.isOwnerPanel || summary.isSuperAdminPanel),
                          isSuperOwner: _isSuperOwner,
                          onAssignRole: () => _openAssignRoleSheet(user),
                          onModerate: () => _openBanSheet(user),
                          onCustomId: () => _openCustomIdSheet(user),
                          onVip: () => _openVipSheet(user),
                          onPermission: () => _openGrantPermissionSheet(user),
                        ),
                      ),
                      if (_isSuperOwner) ...[
                        const SizedBox(height: 14),
                        _LogsCard(logs: _logs),
                        const SizedBox(height: 14),
                        _ReviewsCard(reviews: _reviews),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});
  final AdminControlSummary summary;
  @override
  Widget build(BuildContext context) {
    final colors = summary.isSuperOwnerPanel ? const [Color(0xFF120D1F), Color(0xFF4A2A63), Color(0xFFFFC857)] : const [Color(0xFF251538), Color(0xFF4A2A63), Color(0xFF12C7B7)];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: LinearGradient(colors: colors), borderRadius: BorderRadius.circular(26), boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.14), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(summary.isSuperOwnerPanel ? Icons.workspace_premium_rounded : Icons.admin_panel_settings_rounded, color: const Color(0xFFFFC857), size: 26), const SizedBox(width: 9), Expanded(child: Text(summary.currentPrimaryRole.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)))]),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [_MetricPill(label: 'Users', value: '${summary.usersCount}'), _MetricPill(label: 'Active', value: '${summary.activeUsersCount}'), _MetricPill(label: 'Banned', value: '${summary.bannedUsersCount}'), _MetricPill(label: 'Officials', value: '${summary.officialUsersCount}'), _MetricPill(label: 'Audit', value: '${summary.recentAuditCount}')]),
        const SizedBox(height: 12),
        Text(summary.isSuperOwnerPanel ? 'Founder-only controls are backed by DB tables and audit logs.' : 'Official panel is permission-scoped by backend role rules.', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _SuperOwnerActionsCard extends StatelessWidget {
  const _SuperOwnerActionsCard({required this.onMint, required this.onSendAll, required this.onStealth});
  final VoidCallback onMint;
  final VoidCallback onSendAll;
  final VoidCallback onStealth;
  @override
  Widget build(BuildContext context) => _WhiteCard(children: [
        const _SectionHeader(title: 'Super Owner actions', subtitle: 'DB + audit'),
        const SizedBox(height: 10),
        _ActionTile(icon: Icons.add_circle_rounded, title: 'Mint supply coins', subtitle: 'coin_supply_pools + coin_pool_ledger', onTap: onMint),
        _ActionTile(icon: Icons.groups_rounded, title: 'Send coins to all', subtitle: 'user_wallets + wallet_ledger', onTap: onSendAll),
        _ActionTile(icon: Icons.visibility_off_rounded, title: 'Stealth visibility', subtitle: 'Founder-controlled stealth marker', onTap: onStealth),
      ]);
}

class _PoolsCard extends StatelessWidget {
  const _PoolsCard({required this.pools});
  final List<SuperOwnerPoolItem> pools;
  @override
  Widget build(BuildContext context) => _WhiteCard(children: [
        _SectionHeader(title: 'Coin supply pools', subtitle: '${pools.length}'),
        const SizedBox(height: 8),
        if (pools.isEmpty)
          const Text('No pools yet. Mint coins to create a pool.', style: TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w700))
        else
          ...pools.map((pool) => _CompactRecordCard(icon: Icons.account_balance_wallet_rounded, title: pool.poolType, subtitle: 'Owner ${pool.ownerUserId ?? 'Platform'} • Reserved ${pool.reservedBalance}', status: _fmt(pool.balance))),
      ]);
}

class _LogsCard extends StatelessWidget {
  const _LogsCard({required this.logs});
  final List<SuperOwnerLogItem> logs;
  @override
  Widget build(BuildContext context) => _WhiteCard(children: [
        _SectionHeader(title: 'Audit logs', subtitle: '${logs.length}'),
        const SizedBox(height: 8),
        if (logs.isEmpty)
          const Text('No logs loaded.', style: TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w700))
        else
          ...logs.take(8).map((log) => _CompactRecordCard(icon: Icons.receipt_long_rounded, title: log.action, subtitle: log.reason.isEmpty ? 'Actor ${log.actorUserId ?? '-'} → Target ${log.targetUserId ?? '-'}' : log.reason, status: log.resourceType ?? 'audit')),
      ]);
}

class _ReviewsCard extends StatelessWidget {
  const _ReviewsCard({required this.reviews});
  final List<SuperOwnerReviewItem> reviews;
  @override
  Widget build(BuildContext context) => _WhiteCard(children: [
        _SectionHeader(title: 'Review queue', subtitle: '${reviews.length}'),
        const SizedBox(height: 8),
        if (reviews.isEmpty)
          const Text('No review items loaded.', style: TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w700))
        else
          ...reviews.take(8).map((item) => _CompactRecordCard(icon: Icons.fact_check_rounded, title: item.title, subtitle: item.reason, status: item.status)),
      ]);
}

class _AdminUserCard extends StatelessWidget {
  const _AdminUserCard({required this.user, required this.canAssign, required this.canModerate, required this.isSuperOwner, required this.onAssignRole, required this.onModerate, required this.onCustomId, required this.onVip, required this.onPermission});
  final AdminUser user;
  final bool canAssign;
  final bool canModerate;
  final bool isSuperOwner;
  final VoidCallback onAssignRole;
  final VoidCallback onModerate;
  final VoidCallback onCustomId;
  final VoidCallback onVip;
  final VoidCallback onPermission;
  @override
  Widget build(BuildContext context) {
    final danger = user.isBanned || !user.isActive;
    final initial = user.title.trim().isEmpty ? 'U' : user.title.trim().substring(0, 1).toUpperCase();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFEDE3D7))),
      child: Column(children: [
        Row(children: [
          CircleAvatar(backgroundColor: danger ? const Color(0xFFE84C72) : const Color(0xFF12C7B7), child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(user.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF251538), fontSize: 14.5, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text('ID ${user.publicUserId} • ${user.roleLabel}', style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w800))])),
          IconButton(onPressed: canModerate && user.isNormalUser ? onModerate : null, icon: Icon(user.isBanned ? Icons.lock_open_rounded : Icons.block_rounded)),
          IconButton(onPressed: canAssign ? onAssignRole : null, icon: const Icon(Icons.manage_accounts_rounded)),
        ]),
        if (isSuperOwner) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _MiniButton(label: 'Custom ID', icon: Icons.badge_rounded, onTap: onCustomId),
            _MiniButton(label: 'VIP/SVIP', icon: Icons.workspace_premium_rounded, onTap: onVip),
            _MiniButton(label: 'Permission', icon: Icons.key_rounded, onTap: onPermission),
          ]),
        ],
      ]),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(leading: Icon(icon, color: const Color(0xFF12C7B7)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right_rounded), onTap: onTap);
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ActionChip(avatar: Icon(icon, size: 16), label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)), onPressed: onTap);
}

class _WhiteCard extends StatelessWidget {
  const _WhiteCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFEDE3D7))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children));
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Row(children: [Expanded(child: Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 18, fontWeight: FontWeight.w900))), Text(subtitle, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w800))]);
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999)), child: Text('$label $value', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)));
}

class _UserBanCard extends StatelessWidget {
  const _UserBanCard({required this.ban});
  final UserBanItem ban;
  @override
  Widget build(BuildContext context) => _CompactRecordCard(icon: Icons.block_rounded, title: 'User ${ban.userId}', subtitle: ban.reason, status: ban.isActive ? 'Active' : 'Lifted');
}

class _DeviceBanCard extends StatelessWidget {
  const _DeviceBanCard({required this.ban, required this.onUnban});
  final DeviceBanItem ban;
  final VoidCallback onUnban;
  @override
  Widget build(BuildContext context) => _CompactRecordCard(icon: Icons.phonelink_lock_rounded, title: ban.deviceId, subtitle: ban.reason, status: ban.isActive ? 'Active' : 'Lifted', trailing: IconButton(onPressed: ban.isActive ? onUnban : null, icon: const Icon(Icons.lock_open_rounded)));
}

class _CompactRecordCard extends StatelessWidget {
  const _CompactRecordCard({required this.icon, required this.title, required this.subtitle, required this.status, this.trailing});
  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFEDE3D7))), child: Row(children: [Icon(icon, color: const Color(0xFFE84C72), size: 20), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w900)), Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11, fontWeight: FontWeight.w700))])), Text(status, style: const TextStyle(color: Color(0xFFE84C72), fontSize: 11, fontWeight: FontWeight.w900)), ?trailing]));
}

class _ControlSheet extends StatelessWidget {
  const _ControlSheet({required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.all(14), padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.paddingOf(context).bottom), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 26, offset: const Offset(0, 12))]), child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0D5CB), borderRadius: BorderRadius.circular(999)))), const SizedBox(height: 14), Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 6), Text(subtitle, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w700)), const SizedBox(height: 14), child])));
}

class _ReasonField extends StatelessWidget {
  const _ReasonField({required this.controller});
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) => TextField(controller: controller, minLines: 2, maxLines: 3, decoration: InputDecoration(labelText: 'Reason required', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))));
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({required this.busy, required this.label, required this.busyLabel, required this.icon, required this.onPressed, this.danger = false});
  final bool busy;
  final String label;
  final String busyLabel;
  final IconData icon;
  final VoidCallback onPressed;
  final bool danger;
  @override
  Widget build(BuildContext context) => SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: danger ? const Color(0xFFE84C72) : const Color(0xFF12C7B7), foregroundColor: Colors.white), onPressed: busy ? null : onPressed, icon: Icon(icon), label: Text(busy ? busyLabel : label)));
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.lock_rounded, color: Color(0xFFE84C72), size: 38), const SizedBox(height: 12), Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w800)), const SizedBox(height: 14), ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry'))])));
}

String _fmt(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final remaining = raw.length - i;
    buffer.write(raw[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}
