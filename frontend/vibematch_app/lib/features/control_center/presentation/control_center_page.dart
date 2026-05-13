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
  bool _loading = true;
  bool _assigning = false;
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
      final results = await Future.wait<Object>([
        _apiService.loadSummary(),
        _apiService.loadUsers(),
        _apiService.loadRoleOptions(),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as AdminControlSummary;
        _users = results[1] as List<AdminUser>;
        _roles = results[2] as List<RoleOption>;
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
    final reasonController = TextEditingController(text: 'Control Center role update');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              margin: const EdgeInsets.all(14),
              padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.paddingOf(context).bottom),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 26, offset: const Offset(0, 12))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0D5CB), borderRadius: BorderRadius.circular(999)))),
                  const SizedBox(height: 14),
                  Text('Assign role to ${user.title}', style: const TextStyle(color: Color(0xFF251538), fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text('User ID ${user.publicUserId} • Current ${user.roleLabel}', style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<RoleOption>(
                    value: selected,
                    decoration: InputDecoration(
                      labelText: 'New role',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    items: assignableRoles.map((role) {
                      return DropdownMenuItem<RoleOption>(
                        value: role,
                        child: Text('${role.label} • P${role.power}'),
                      );
                    }).toList(growable: false),
                    onChanged: (role) {
                      if (role == null) return;
                      setSheetState(() => selected = role);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    minLines: 2,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Reason required',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _assigning
                          ? null
                          : () async {
                              final reason = reasonController.text.trim();
                              if (reason.isEmpty) {
                                _toast('Reason is required.', danger: true);
                                return;
                              }
                              setState(() => _assigning = true);
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
                                if (mounted) setState(() => _assigning = false);
                              }
                            },
                      icon: const Icon(Icons.verified_user_rounded),
                      label: Text(_assigning ? 'Assigning...' : 'Assign role'),
                    ),
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

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F1),
        foregroundColor: const Color(0xFF251538),
        elevation: 0,
        title: const Text('Control Center', style: TextStyle(fontWeight: FontWeight.w900)),
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
                      Row(
                        children: [
                          const Expanded(child: Text('Users & roles', style: TextStyle(color: Color(0xFF251538), fontSize: 18, fontWeight: FontWeight.w900))),
                          Text('${_users.length} shown', style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ..._users.map((user) => _AdminUserCard(user: user, canAssign: summary?.canAssignRoles == true, onAssignRole: () => _openAssignRoleSheet(user))),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF251538), Color(0xFF4A2A63)]),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.14), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFFFC857), size: 24),
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
            summary.canAssignRoles ? 'Role assignment enabled for Founder Owner.' : 'Role assignment is view-only for this account.',
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
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
  const _AdminUserCard({required this.user, required this.canAssign, required this.onAssignRole});
  final AdminUser user;
  final bool canAssign;
  final VoidCallback onAssignRole;

  @override
  Widget build(BuildContext context) {
    final danger = user.isBanned || !user.isActive;
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
            child: Text(user.title.isEmpty ? 'U' : user.title.characters.first.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
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
          IconButton(onPressed: canAssign ? onAssignRole : null, icon: const Icon(Icons.manage_accounts_rounded)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_rounded, color: Color(0xFFE84C72), size: 38),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
