import 'package:flutter/material.dart';

import '../data/control_center_api_service.dart';

class ControlCenterPage extends StatefulWidget {
  const ControlCenterPage({super.key});

  @override
  State<ControlCenterPage> createState() => _ControlCenterPageState();
}

class _ControlCenterPageState extends State<ControlCenterPage> {
  final ControlCenterApiService _apiService = ControlCenterApiService();

  AdminControlSummary? _summary;
  List<AdminUser> _users = const <AdminUser>[];
  List<RoleOption> _roles = const <RoleOption>[];
  List<UserBanItem> _userBans = const <UserBanItem>[];
  List<DeviceBanItem> _deviceBans = const <DeviceBanItem>[];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _apiService.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await _apiService.loadSummary();
      final users = await _apiService.loadUsers();
      final roles = await _apiService.loadRoleOptions();
      var bans = const <UserBanItem>[];
      var deviceBans = const <DeviceBanItem>[];
      try {
        bans = await _apiService.loadUserBans();
      } catch (_) {}
      if (summary.isSuperOwnerPanel) {
        try {
          deviceBans = await _apiService.loadDeviceBans();
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _users = users;
        _roles = roles;
        _userBans = bans;
        _deviceBans = deviceBans;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

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

  String _firstLetter(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return 'U';
    return clean.substring(0, 1).toUpperCase();
  }

  Future<void> _openAssignRoleSheet(AdminUser user) async {
    final summary = _summary;
    final assignableRoles = _roles.where((role) => role.assignable).toList(growable: false);
    if (summary == null || !summary.canAssignRoles || assignableRoles.isEmpty) {
      _toast('Founder Owner access is required to assign official roles.', danger: true);
      return;
    }

    RoleOption selected = assignableRoles.firstWhere(
      (role) => role.value == user.primaryRole,
      orElse: () => assignableRoles.first,
    );
    final reasonController = TextEditingController(text: 'Super Owner control panel role update');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _ControlSheet(
              title: 'Assign role to ${user.title}',
              subtitle: 'User ID ${user.publicUserId} • Current ${user.roleLabel}',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<RoleOption>(
                    value: selected,
                    decoration: InputDecoration(labelText: 'New role', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
                    items: assignableRoles.map((role) => DropdownMenuItem<RoleOption>(value: role, child: Text('${role.label} • P${role.power}'))).toList(growable: false),
                    onChanged: (role) {
                      if (role == null) return;
                      setSheetState(() => selected = role);
                    },
                  ),
                  const SizedBox(height: 12),
                  _ReasonField(controller: reasonController),
                  const SizedBox(height: 14),
                  _PrimaryActionButton(
                    busy: _busy,
                    label: 'Assign role',
                    busyLabel: 'Assigning...',
                    icon: Icons.verified_user_rounded,
                    onPressed: () async {
                      final reason = reasonController.text.trim();
                      if (reason.isEmpty) {
                        _toast('Reason is required.', danger: true);
                        return;
                      }
                      setState(() => _busy = true);
                      try {
                        await _apiService.assignRole(targetUserId: user.id, role: selected.value, reason: reason);
                        if (!mounted) return;
                        Navigator.pop(context);
                        _toast('Role assigned successfully.');
                        await _load();
                      } catch (error) {
                        if (!mounted) return;
                        _toast(error.toString().replaceFirst('Exception: ', ''), danger: true);
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    reasonController.dispose();
  }

  Future<void> _openBanSheet(AdminUser user) async {
    if (!user.isNormalUser) {
      _toast('Only normal users can be banned from this panel.', danger: true);
      return;
    }
    final reasonController = TextEditingController(text: 'Control Center moderation action');
    final deviceController = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ControlSheet(
          title: user.isBanned ? 'Unban ${user.title}' : 'Ban ${user.title}',
          subtitle: 'Normal user ID ${user.publicUserId}',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ReasonField(controller: reasonController),
              if (!user.isBanned) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: deviceController,
                  decoration: InputDecoration(
                    labelText: 'Device ID snapshot (optional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _PrimaryActionButton(
                busy: _busy,
                danger: !user.isBanned,
                label: user.isBanned ? 'Unban user' : 'Ban user',
                busyLabel: user.isBanned ? 'Unbanning...' : 'Banning...',
                icon: user.isBanned ? Icons.lock_open_rounded : Icons.block_rounded,
                onPressed: () async {
                  final reason = reasonController.text.trim();
                  if (reason.isEmpty) {
                    _toast('Reason is required.', danger: true);
                    return;
                  }
                  setState(() => _busy = true);
                  try {
                    if (user.isBanned) {
                      await _apiService.unbanUser(targetUserId: user.id, reason: reason);
                    } else {
                      await _apiService.banUser(targetUserId: user.id, reason: reason, deviceId: deviceController.text);
                    }
                    if (!mounted) return;
                    Navigator.pop(context);
                    _toast(user.isBanned ? 'User unbanned.' : 'User banned.');
                    await _load();
                  } catch (error) {
                    if (!mounted) return;
                    _toast(error.toString().replaceFirst('Exception: ', ''), danger: true);
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
    reasonController.dispose();
    deviceController.dispose();
  }

  Future<void> _openDeviceUnbanSheet(DeviceBanItem ban) async {
    final reasonController = TextEditingController(text: 'Super Owner device unban review');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ControlSheet(
          title: 'Unban device',
          subtitle: ban.deviceId,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ReasonField(controller: reasonController),
              const SizedBox(height: 14),
              _PrimaryActionButton(
                busy: _busy,
                label: 'Unban device',
                busyLabel: 'Unbanning...',
                icon: Icons.phonelink_lock_rounded,
                onPressed: () async {
                  final reason = reasonController.text.trim();
                  if (reason.isEmpty) {
                    _toast('Reason is required.', danger: true);
                    return;
                  }
                  setState(() => _busy = true);
                  try {
                    await _apiService.unbanDevice(deviceId: ban.deviceId, reason: reason);
                    if (!mounted) return;
                    Navigator.pop(context);
                    _toast('Device unbanned.');
                    await _load();
                  } catch (error) {
                    if (!mounted) return;
                    _toast(error.toString().replaceFirst('Exception: ', ''), danger: true);
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
    reasonController.dispose();
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
                      if (summary != null) _PanelToolsCard(summary: summary),
                      const SizedBox(height: 14),
                      if (summary?.isSuperOwnerPanel == true && _deviceBans.isNotEmpty) ...[
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
                      _SectionHeader(title: 'Users & roles', subtitle: '${_users.length} shown'),
                      const SizedBox(height: 10),
                      ..._users.map(
                        (user) => _AdminUserCard(
                          user: user,
                          canAssign: summary?.canAssignRoles == true,
                          canModerate: summary != null && (summary.isSuperOwnerPanel || summary.isOwnerPanel || summary.isSuperAdminPanel),
                          onAssignRole: () => _openAssignRoleSheet(user),
                          onModerate: () => _openBanSheet(user),
                        ),
                      ),
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
    final colors = summary.isSuperOwnerPanel
        ? const [Color(0xFF120D1F), Color(0xFF4A2A63), Color(0xFFFFC857)]
        : summary.isOwnerPanel
            ? const [Color(0xFF251538), Color(0xFF8C5CF6), Color(0xFF12C7B7)]
            : const [Color(0xFF251538), Color(0xFF4A2A63), Color(0xFF12C7B7)];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.14), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(summary.isSuperOwnerPanel ? Icons.workspace_premium_rounded : Icons.admin_panel_settings_rounded, color: const Color(0xFFFFC857), size: 26),
              const SizedBox(width: 9),
              Expanded(child: Text(summary.currentPrimaryRole.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricPill(label: 'Users', value: '${summary.usersCount}'),
              _MetricPill(label: 'Active', value: '${summary.activeUsersCount}'),
              _MetricPill(label: 'Banned', value: '${summary.bannedUsersCount}'),
              _MetricPill(label: 'Officials', value: '${summary.officialUsersCount}'),
              _MetricPill(label: 'Audit', value: '${summary.recentAuditCount}'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            summary.isSuperOwnerPanel
                ? 'Full Super Owner controls enabled with backend role/audit enforcement.'
                : summary.isOwnerPanel
                    ? 'Owner panel enabled for high-level operational oversight and normal-user moderation.'
                    : 'Official panel is permission-scoped by backend role rules.',
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _PanelToolsCard extends StatelessWidget {
  const _PanelToolsCard({required this.summary});
  final AdminControlSummary summary;

  @override
  Widget build(BuildContext context) {
    final items = summary.isSuperOwnerPanel
        ? const [
            _ToolInfo(Icons.manage_accounts_rounded, 'Roles', 'Assign all lower official roles'),
            _ToolInfo(Icons.block_rounded, 'Bans', 'Ban/unban normal users'),
            _ToolInfo(Icons.phonelink_lock_rounded, 'Devices', 'Review and unban devices'),
            _ToolInfo(Icons.receipt_long_rounded, 'Audit', 'View protected audit history'),
          ]
        : summary.isOwnerPanel
            ? const [
                _ToolInfo(Icons.shield_rounded, 'Oversight', 'Review users and officials'),
                _ToolInfo(Icons.block_rounded, 'Moderation', 'Ban/unban normal users'),
                _ToolInfo(Icons.groups_rounded, 'Operations', 'Monitor teams and reports'),
              ]
            : const [
                _ToolInfo(Icons.visibility_rounded, 'View', 'Role-scoped dashboard'),
                _ToolInfo(Icons.report_rounded, 'Reports', 'Review allowed queues'),
              ];
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFEDE3D7))),
      child: Column(
        children: items.map((item) => _ToolInfoRow(item: item)).toList(growable: false),
      ),
    );
  }
}

class _ToolInfo {
  const _ToolInfo(this.icon, this.title, this.subtitle);
  final IconData icon;
  final String title;
  final String subtitle;
}

class _ToolInfoRow extends StatelessWidget {
  const _ToolInfoRow({required this.item});
  final _ToolInfo item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFF12C7B7).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)), child: Icon(item.icon, color: const Color(0xFF12C7B7), size: 19)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.title, style: const TextStyle(color: Color(0xFF251538), fontSize: 13, fontWeight: FontWeight.w900)), Text(item.subtitle, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11, fontWeight: FontWeight.w700))])),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(children: [Expanded(child: Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 18, fontWeight: FontWeight.w900))), Text(subtitle, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w800))]);
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withValues(alpha: 0.10))),
      child: Text('$label $value', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
    );
  }
}

class _AdminUserCard extends StatelessWidget {
  const _AdminUserCard({required this.user, required this.canAssign, required this.canModerate, required this.onAssignRole, required this.onModerate});
  final AdminUser user;
  final bool canAssign;
  final bool canModerate;
  final VoidCallback onAssignRole;
  final VoidCallback onModerate;

  @override
  Widget build(BuildContext context) {
    final danger = user.isBanned || !user.isActive;
    final initial = user.title.trim().isEmpty ? 'U' : user.title.trim().substring(0, 1).toUpperCase();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFEDE3D7))),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: danger ? const [Color(0xFFE84C72), Color(0xFFC99A3B)] : const [Color(0xFF12C7B7), Color(0xFF8C5CF6)])),
            child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF251538), fontSize: 14.5, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text('ID ${user.publicUserId} • ${user.roleLabel}', style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w800)),
                if (danger) ...[
                  const SizedBox(height: 4),
                  Text(user.isBanned ? 'Banned' : 'Inactive', style: const TextStyle(color: Color(0xFFE84C72), fontSize: 11, fontWeight: FontWeight.w900)),
                ],
              ],
            ),
          ),
          IconButton(onPressed: canModerate && user.isNormalUser ? onModerate : null, icon: Icon(user.isBanned ? Icons.lock_open_rounded : Icons.block_rounded)),
          IconButton(onPressed: canAssign ? onAssignRole : null, icon: const Icon(Icons.manage_accounts_rounded)),
        ],
      ),
    );
  }
}

class _UserBanCard extends StatelessWidget {
  const _UserBanCard({required this.ban});
  final UserBanItem ban;

  @override
  Widget build(BuildContext context) {
    return _CompactRecordCard(icon: Icons.block_rounded, title: 'User ${ban.userId}', subtitle: ban.reason, status: ban.isActive ? 'Active' : 'Lifted');
  }
}

class _DeviceBanCard extends StatelessWidget {
  const _DeviceBanCard({required this.ban, required this.onUnban});
  final DeviceBanItem ban;
  final VoidCallback onUnban;

  @override
  Widget build(BuildContext context) {
    return _CompactRecordCard(icon: Icons.phonelink_lock_rounded, title: ban.deviceId, subtitle: ban.reason, status: ban.isActive ? 'Active' : 'Lifted', trailing: IconButton(onPressed: ban.isActive ? onUnban : null, icon: const Icon(Icons.lock_open_rounded)));
  }
}

class _CompactRecordCard extends StatelessWidget {
  const _CompactRecordCard({required this.icon, required this.title, required this.subtitle, required this.status, this.trailing});
  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFEDE3D7))),
      child: Row(children: [Icon(icon, color: const Color(0xFFE84C72), size: 20), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w900)), Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11, fontWeight: FontWeight.w700))])), Text(status, style: const TextStyle(color: Color(0xFFE84C72), fontSize: 11, fontWeight: FontWeight.w900)), if (trailing != null) trailing!]),
    );
  }
}

class _ControlSheet extends StatelessWidget {
  const _ControlSheet({required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 26, offset: const Offset(0, 12))]),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0D5CB), borderRadius: BorderRadius.circular(999)))),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          child,
        ]),
      ),
    );
  }
}

class _ReasonField extends StatelessWidget {
  const _ReasonField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(controller: controller, minLines: 2, maxLines: 3, decoration: InputDecoration(labelText: 'Reason required', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))));
  }
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
  Widget build(BuildContext context) {
    return SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: danger ? const Color(0xFFE84C72) : const Color(0xFF12C7B7), foregroundColor: Colors.white), onPressed: busy ? null : onPressed, icon: Icon(icon), label: Text(busy ? busyLabel : label)));
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.lock_rounded, color: Color(0xFFE84C72), size: 38), const SizedBox(height: 12), Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w800)), const SizedBox(height: 14), ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry'))])));
  }
}
