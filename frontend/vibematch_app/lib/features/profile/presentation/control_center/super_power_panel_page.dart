import 'package:flutter/material.dart';

import 'control_center_models.dart';
import 'control_center_store.dart';
import 'widgets/control_action_sheets.dart';
import 'widgets/control_deck_widgets.dart';
import 'widgets/control_performance_panel.dart';
import 'widgets/control_power_categories_panel.dart';
import 'widgets/control_review_panel.dart';
import 'widgets/control_role_panel.dart';
import 'widgets/control_simple_overview.dart';
import 'widgets/super_power_design.dart';

class SuperPowerPanelPage extends StatefulWidget {
  const SuperPowerPanelPage({super.key, required this.currentRole});

  final String currentRole;

  @override
  State<SuperPowerPanelPage> createState() => _SuperPowerPanelPageState();
}

class _SuperPowerPanelPageState extends State<SuperPowerPanelPage> {
  ControlCenterState? _state;
  ControlCenterSection _section = ControlCenterSection.overview;
  bool _busy = false;

  bool get _allowed {
    final role = widget.currentRole.toLowerCase().trim();
    return role == 'founder_owner' || role == 'super_owner' || role == 'owner';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = await ControlCenterStore.load();
    if (!mounted) return;
    setState(() => _state = state);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: SuperPowerDesign.obsidian, content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800))));
  }

  Future<void> _save(
    ControlCenterState Function(ControlCenterState state) change, {
    String? action,
    String targetUserId = '-',
    String roomId = '-',
    String resourceType = 'control_center',
    String reason = 'Super power panel update',
  }) async {
    final current = _state;
    if (current == null || _busy) return;
    setState(() => _busy = true);
    var next = change(current);
    if (action == null) {
      await ControlCenterStore.save(next);
    } else {
      next = await ControlCenterStore.writeLog(next, action: action, targetUserId: targetUserId, chatRoomId: roomId, resourceType: resourceType, reason: reason);
    }
    if (!mounted) return;
    setState(() {
      _state = next;
      _busy = false;
    });
  }

  Future<void> _setGlobalStealth(bool value) async {
    await _save(
      (state) => state.copyWith(globalInvisible: value),
      action: value ? 'INVISIBILITY_ON' : 'INVISIBILITY_OFF',
      resourceType: 'presence',
      reason: 'Global stealth toggled from Super Owner overview',
    );
    _toast(value ? 'Stealth mode enabled.' : 'Stealth mode disabled.');
  }

  Future<void> _changePool({required bool add}) async {
    final draft = await ControlNumberSheet.show(context, title: add ? 'Mint coins into authority pool' : 'Remove coins from authority pool');
    if (draft == null) return;
    await _save(
      (state) => state.copyWith(
        coinAuthorityBalance: add ? state.coinAuthorityBalance + draft.amount : (state.coinAuthorityBalance - draft.amount).clamp(0, 1 << 62),
      ),
      action: add ? 'AUTHORITY_POOL_MINTED' : 'AUTHORITY_POOL_REMOVED',
      resourceType: 'authority_pool',
      reason: '${draft.amount} coins',
    );
    _toast(add ? 'Authority pool minted.' : 'Authority pool reduced.');
  }

  Future<void> _sendCoins() async {
    final draft = await ControlUserNumberSheet.show(context, title: 'Send coins to user');
    if (draft == null) return;
    await _save(
      (state) => state.copyWith(coinAuthorityBalance: (state.coinAuthorityBalance - draft.amount).clamp(0, 1 << 62)),
      action: 'COINS_SENT',
      targetUserId: draft.userId,
      resourceType: 'wallet',
      reason: '${draft.amount} coins',
    );
    _toast('Coins sent.');
  }

  Future<void> _assignCustomId() async {
    final draft = await ControlCustomIdSheet.show(context);
    if (draft == null) return;

    final action = draft.targetType == 'room'
        ? 'ROOM_CUSTOM_ID_ASSIGNED'
        : 'USER_CUSTOM_ID_ASSIGNED';

    await _save(
      (state) => state,
      action: action,
      targetUserId: draft.targetType == 'user' ? draft.targetId : '-',
      roomId: draft.targetType == 'room' ? draft.targetId : '-',
      resourceType: '_custom_id',
      reason: 'custom_id= | validity=',
    );

    _toast(' custom ID assigned.');
  }

  Future<void> _grantPower() async {
    final draft = await ControlPowerSheet.show(context);
    if (draft == null) return;
    await _save(
      (state) => state.copyWith(
        powerGrants: <PowerGrantEntry>[
          PowerGrantEntry(
            id: 'PWR-${DateTime.now().millisecondsSinceEpoch}',
            userId: draft.userId,
            role: draft.role,
            authorities: draft.authorities,
            reason: draft.reason,
            isActive: true,
            createdAt: DateTime.now(),
          ),
          ...state.powerGrants,
        ],
      ),
      action: 'POWER_GRANTED',
      targetUserId: draft.userId,
      resourceType: 'special_permission',
      reason: draft.reason,
    );
    _toast('Power granted.');
  }

  Future<void> _togglePower(PowerGrantEntry grant) async {
    await _save(
      (state) => state.copyWith(
        powerGrants: state.powerGrants.map((item) => item.id == grant.id ? item.copyWith(isActive: !item.isActive) : item).toList(),
      ),
      action: grant.isActive ? 'POWER_REVOKED' : 'POWER_RESTORED',
      targetUserId: grant.userId,
      resourceType: 'special_permission',
      reason: grant.reason,
    );
  }

  Future<void> _assignRole() async {
    final draft = await RoleAssignSheet.show(context);
    if (draft == null) return;
    await _save(
      (state) => state.copyWith(
        roleAssignments: <RoleAssignmentEntry>[
          RoleAssignmentEntry(
            id: 'ROLE-${DateTime.now().millisecondsSinceEpoch}',
            userId: draft.userId,
            role: draft.role,
            assignedByUserId: '6922022',
            reason: draft.reason,
            isActive: true,
            createdAt: DateTime.now(),
          ),
          ...state.roleAssignments,
        ],
      ),
      action: 'ROLE_ASSIGNED',
      targetUserId: draft.userId,
      resourceType: 'user_role',
      reason: '${draft.role}: ${draft.reason}',
    );
    _toast('Official role assigned.');
  }

  Future<void> _removeRole(RoleAssignmentEntry role) async {
    await _save(
      (state) => state.copyWith(
        roleAssignments: state.roleAssignments.map((item) => item.id == role.id ? item.copyWith(isActive: false, removedAt: DateTime.now()) : item).toList(),
      ),
      action: 'ROLE_REMOVED',
      targetUserId: role.userId,
      resourceType: 'user_role',
      reason: 'Removed ${role.role}',
    );
    _toast('Official role removed.');
  }

  Future<void> _userAction(String action) async {
    final draft = await ControlUserTextSheet.show(context, title: action, label: 'Reason / days / device ID');
    if (draft == null) return;
    await _save((state) => state, action: action, targetUserId: draft.userId, resourceType: 'user_action', reason: draft.text);
    _toast('$action logged.');
  }

  Future<void> _showUserControl() async {
    final draft = await _SuperOwnerUserActionSheet.show(context);
    if (draft == null) return;
    await _save(
      (state) => state,
      action: draft.action,
      targetUserId: draft.userId,
      resourceType: draft.resourceType,
      reason: draft.reason,
    );
    _toast('${draft.label} logged.');
  }

  Future<void> _review(ReviewQueueItem item, String status) async {
    await _save(
      (state) => state.copyWith(
        reviewItems: state.reviewItems.map((entry) => entry.id == item.id ? entry.copyWith(status: status) : entry).toList(),
      ),
      action: 'REVIEW_${status.toUpperCase()}',
      targetUserId: item.userId,
      roomId: item.roomId,
      resourceType: item.type,
      reason: item.title,
    );
    _toast('Review $status.');
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    return Scaffold(
      backgroundColor: SuperPowerDesign.bg,
      body: SafeArea(
        child: !_allowed
            ? _Denied(onBack: () => Navigator.pop(context))
            : state == null
                ? const Center(child: CircularProgressIndicator(color: SuperPowerDesign.gold))
                : CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _Header(state: state, busy: _busy, onBack: () => Navigator.pop(context))),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _NavDelegate(selected: _section, onSelected: (value) => setState(() => _section = value)),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                        sliver: SliverToBoxAdapter(child: _body(state)),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _body(ControlCenterState state) {
    return switch (_section) {
      ControlCenterSection.overview => ControlSimpleOverview(
          state: state,
          onStealthChanged: _setGlobalStealth,
          onMint: () => _changePool(add: true),
          onSendCoins: _sendCoins,
          onUserControl: _showUserControl,
          onPowerControl: () => setState(() => _section = ControlCenterSection.powers),
          onRoleControl: () => setState(() => _section = ControlCenterSection.powers),
          onReview: () => setState(() => _section = ControlCenterSection.review),
          onPerformance: () => setState(() => _section = ControlCenterSection.performance),
        ),
      ControlCenterSection.performance => const ControlPerformancePanel(),
      ControlCenterSection.invisibility => _Stealth(state: state, save: _save),
      ControlCenterSection.logs => _Logs(logs: state.logs),
      ControlCenterSection.powers => Column(
          children: [
            ControlRolePanel(roles: state.roleAssignments, onAssignRole: _assignRole, onRemoveRole: _removeRole),
            const SizedBox(height: 12),
            ControlPowerCategoriesPanel(grants: state.powerGrants, onGrantPower: _grantPower, onToggleGrant: _togglePower),
          ],
        ),
      ControlCenterSection.bans => _UserAuthority(onAction: _userAction),
      ControlCenterSection.review => ControlReviewPanel(
          items: state.reviewItems,
          onApprove: (item) => _review(item, 'Approved'),
          onReject: (item) => _review(item, 'Rejected'),
        ),
      ControlCenterSection.economy => _Economy(
          state: state,
          onMint: () => _changePool(add: true),
          onRemovePool: () => _changePool(add: false),
          onSendCoins: _sendCoins,
        ),
      ControlCenterSection.identity => _Identity(onAssignCustomId: _assignCustomId),
    };
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state, required this.busy, required this.onBack});
  final ControlCenterState state;
  final bool busy;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      padding: const EdgeInsets.all(14),
      decoration: SuperPowerDesign.glowShell(radius: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _RoundIcon(icon: Icons.arrow_back_rounded, onTap: onBack),
          const SizedBox(width: 10),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Super Owner Panel', style: TextStyle(color: SuperPowerDesign.text, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            Text('Master controls - simple view', style: TextStyle(color: SuperPowerDesign.muted, fontSize: 11, fontWeight: FontWeight.w800)),
          ])),
          if (busy) const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(color: SuperPowerDesign.gold, strokeWidth: 2)),
        ]),
      ]),
    );
  }
}

class _NavDelegate extends SliverPersistentHeaderDelegate {
  _NavDelegate({required this.selected, required this.onSelected});
  final ControlCenterSection selected;
  final ValueChanged<ControlCenterSection> onSelected;

  static const List<ControlCenterSection> _visibleSections = <ControlCenterSection>[
    ControlCenterSection.overview,
    ControlCenterSection.powers,
    ControlCenterSection.bans,
    ControlCenterSection.review,
    ControlCenterSection.performance,
    ControlCenterSection.logs,
  ];

  @override
  double get minExtent => 50;
  @override
  double get maxExtent => 50;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: SuperPowerDesign.bg,
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _visibleSections.length,
        separatorBuilder: (context, index) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final item = _visibleSections[index];
          final active = item == selected;
          return InkWell(
            onTap: () => onSelected(item),
            borderRadius: BorderRadius.circular(999),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: active ? SuperPowerDesign.gold : SuperPowerDesign.panel,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: active ? SuperPowerDesign.gold : SuperPowerDesign.stroke),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(item.icon, size: 15, color: active ? SuperPowerDesign.obsidian : SuperPowerDesign.text),
                const SizedBox(width: 6),
                Text(item.label, style: TextStyle(color: active ? SuperPowerDesign.obsidian : SuperPowerDesign.text, fontSize: 11, fontWeight: FontWeight.w900)),
              ]),
            ),
          );
        },
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _NavDelegate oldDelegate) => oldDelegate.selected != selected;
}

class _Economy extends StatelessWidget {
  const _Economy({required this.state, required this.onMint, required this.onRemovePool, required this.onSendCoins});
  final ControlCenterState state;
  final VoidCallback onMint;
  final VoidCallback onRemovePool;
  final VoidCallback onSendCoins;

  @override
  Widget build(BuildContext context) => ControlDeckShell(
        title: 'Founder Coin Pool',
        subtitle: 'Authority pool is Founder-controlled and audit logged.',
        trailing: const ControlDeckPill(label: 'INFINITE'),
        children: [
          _Vault(balance: state.coinAuthorityBalance),
          const SizedBox(height: 10),
          ControlDeckRow(icon: Icons.add_circle_rounded, title: 'Mint into authority pool', subtitle: 'Increase Founder supply pool', accent: SuperPowerDesign.gold, onTap: onMint),
          ControlDeckRow(icon: Icons.remove_circle_rounded, title: 'Remove from authority pool', subtitle: 'Reduce pool for accounting correction', accent: SuperPowerDesign.rose, onTap: onRemovePool),
          ControlDeckRow(icon: Icons.send_rounded, title: 'Send coins to user', subtitle: 'Target user ID + amount', accent: SuperPowerDesign.mint, onTap: onSendCoins),
        ],
      );
}

class _Stealth extends StatelessWidget {
  const _Stealth({required this.state, required this.save});
  final ControlCenterState state;
  final Future<void> Function(ControlCenterState Function(ControlCenterState), {String? action, String targetUserId, String roomId, String resourceType, String reason}) save;

  @override
  Widget build(BuildContext context) => ControlDeckShell(
        title: 'Invisible Authority',
        subtitle: 'Hide allover app, from online count, and even when seated.',
        children: [
          _SwitchCommand(title: 'Invisible allover app', value: state.globalInvisible, onChanged: (value) => save((s) => s.copyWith(globalInvisible: value), action: value ? 'INVISIBILITY_ON' : 'INVISIBILITY_OFF', resourceType: 'presence', reason: 'Global invisibility changed')),
          _SwitchCommand(title: 'Hide from online count', value: state.hideFromOnlineCount, onChanged: (value) => save((s) => s.copyWith(hideFromOnlineCount: value), action: 'ONLINE_COUNT_VISIBILITY_CHANGED', resourceType: 'presence', reason: 'Online count visibility changed')),
          _SwitchCommand(title: 'Hide even when seated', value: state.hideWhenSeated, onChanged: (value) => save((s) => s.copyWith(hideWhenSeated: value), action: 'SEAT_VISIBILITY_CHANGED', resourceType: 'room_seat', reason: 'Seat visibility changed')),
          _SwitchCommand(title: 'Hide room entry events', value: state.hideRoomEntryEvents, onChanged: (value) => save((s) => s.copyWith(hideRoomEntryEvents: value), action: 'ROOM_ENTRY_VISIBILITY_CHANGED', resourceType: 'chat_room', reason: 'Room entry visibility changed')),
          _SwitchCommand(title: 'Keep private audit logs', value: state.auditInvisibleAccess, onChanged: (value) => save((s) => s.copyWith(auditInvisibleAccess: value), action: 'INVISIBLE_AUDIT_CHANGED', resourceType: 'admin_log', reason: 'Invisible audit changed')),
        ],
      );
}

class _UserAuthority extends StatelessWidget {
  const _UserAuthority({required this.onAction});
  final Future<void> Function(String action) onAction;
  @override
  Widget build(BuildContext context) => ControlDeckShell(
        title: 'User Authority',
        subtitle: 'Super Owner user actions with reason logs.',
        children: [
          ControlDeckRow(icon: Icons.timer_rounded, title: 'Custom ban days', subtitle: 'Select any number of ban days for a user', accent: SuperPowerDesign.gold, onTap: () => onAction('CUSTOM_BAN_DAYS')),
          ControlDeckRow(icon: Icons.devices_other_rounded, title: 'Device ban', subtitle: 'Permanent device-level action', accent: SuperPowerDesign.rose, onTap: () => onAction('DEVICE_BAN')),
          ControlDeckRow(icon: Icons.block_rounded, title: 'Ban user', subtitle: 'User ban with reason', accent: SuperPowerDesign.rose, onTap: () => onAction('BAN_USER')),
          ControlDeckRow(icon: Icons.lock_open_rounded, title: 'Unban / restore user', subtitle: 'Restore access', accent: SuperPowerDesign.aqua, onTap: () => onAction('UNBAN_USER')),
        ],
      );
}

class _Identity extends StatelessWidget {
  const _Identity({required this.onAssignCustomId});
  final VoidCallback onAssignCustomId;
  @override
  Widget build(BuildContext context) => ControlDeckShell(
        title: 'Identity Authority',
        subtitle: 'Official ID and identity actions.',
        children: [ControlDeckRow(icon: Icons.badge_rounded, title: 'Assign custom ID', subtitle: 'Protected premium ID assignment', accent: SuperPowerDesign.gold, onTap: onAssignCustomId)],
      );
}

class _Logs extends StatefulWidget {
  const _Logs({required this.logs});

  final List<ControlLogEntry> logs;

  @override
  State<_Logs> createState() => _LogsState();
}

class _LogsState extends State<_Logs> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ControlLogEntry> get _filteredLogs {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return widget.logs;

    return widget.logs.where((log) {
      return log.actorUserId.toLowerCase().contains(query) ||
          log.targetUserId.toLowerCase().contains(query) ||
          log.chatRoomId.toLowerCase().contains(query) ||
          log.action.toLowerCase().contains(query) ||
          log.resourceType.toLowerCase().contains(query) ||
          log.reason.toLowerCase().contains(query);
    }).toList();
  }

  bool _isUserExactMatch(ControlLogEntry log, String query) {
    return log.actorUserId.toLowerCase() == query || log.targetUserId.toLowerCase() == query;
  }

  bool _isRoomExactMatch(ControlLogEntry log, String query) {
    return log.chatRoomId.toLowerCase() == query;
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final filtered = _filteredLogs;
    final exactUserLogs = query.isEmpty ? 0 : widget.logs.where((log) => _isUserExactMatch(log, query)).length;
    final exactRoomLogs = query.isEmpty ? 0 : widget.logs.where((log) => _isRoomExactMatch(log, query)).length;

    return ControlDeckShell(
      title: 'Audit Search',
      subtitle: 'Search user ID, actor ID, target ID, room ID, action, resource, or reason.',
      trailing: ControlDeckPill(label: '${filtered.length} logs'),
      children: [
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: SuperPowerDesign.text, fontSize: 13, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            hintText: 'Search user ID or room ID',
            hintStyle: const TextStyle(color: SuperPowerDesign.muted, fontSize: 12, fontWeight: FontWeight.w700),
            prefixIcon: const Icon(Icons.search_rounded, color: SuperPowerDesign.gold, size: 20),
            suffixIcon: _search.text.trim().isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _search.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close_rounded, color: SuperPowerDesign.muted, size: 18),
                  ),
            filled: true,
            fillColor: SuperPowerDesign.obsidian,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: SuperPowerDesign.stroke),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: SuperPowerDesign.stroke),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: SuperPowerDesign.gold),
            ),
          ),
        ),
        if (query.isNotEmpty) ...[
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: _LogSearchStat(
                  label: 'User logs',
                  value: exactUserLogs.toString(),
                  icon: Icons.person_search_rounded,
                  color: SuperPowerDesign.aqua,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _LogSearchStat(
                  label: 'Room logs',
                  value: exactRoomLogs.toString(),
                  icon: Icons.meeting_room_rounded,
                  color: SuperPowerDesign.gold,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        if (filtered.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SuperPowerDesign.obsidian,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SuperPowerDesign.stroke),
            ),
            child: const Text(
              'No logs found for this user ID or room ID.',
              style: TextStyle(color: SuperPowerDesign.muted, fontSize: 12, fontWeight: FontWeight.w800),
            ),
          )
        else
          ...filtered.map((log) {
            final time = log.createdAt.toLocal().toString().split('.').first;
            final roomLabel = log.chatRoomId == '-' ? 'No room' : log.chatRoomId;

            return _DetailedLogRow(
              log: log,
              time: time,
              roomLabel: roomLabel,
            );
          }),
      ],
    );
  }
}

class _LogSearchStat extends StatelessWidget {
  const _LogSearchStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SuperPowerDesign.obsidian,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: SuperPowerDesign.muted, fontSize: 10.5, fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _DetailedLogRow extends StatelessWidget {
  const _DetailedLogRow({
    required this.log,
    required this.time,
    required this.roomLabel,
  });

  final ControlLogEntry log;
  final String time;
  final String roomLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: SuperPowerDesign.obsidian,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SuperPowerDesign.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: SuperPowerDesign.gold, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  log.action,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: SuperPowerDesign.text, fontSize: 12.8, fontWeight: FontWeight.w900),
                ),
              ),
              ControlDeckPill(label: roomLabel),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _LogChip(label: 'Actor', value: log.actorUserId, color: SuperPowerDesign.gold),
              _LogChip(label: 'Target', value: log.targetUserId, color: SuperPowerDesign.aqua),
              _LogChip(label: 'Room', value: roomLabel, color: SuperPowerDesign.violet),
              _LogChip(label: 'Type', value: log.resourceType, color: SuperPowerDesign.mint),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            log.reason.isEmpty ? 'No reason recorded.' : log.reason,
            style: const TextStyle(color: SuperPowerDesign.muted, fontSize: 11, fontWeight: FontWeight.w700, height: 1.25),
          ),
          const SizedBox(height: 6),
          Text(
            time,
            style: const TextStyle(color: SuperPowerDesign.muted, fontSize: 9.8, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _LogChip extends StatelessWidget {
  const _LogChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(color: color, fontSize: 9.6, fontWeight: FontWeight.w900),
      ),
    );
  }
}
class _Vault extends StatelessWidget {
  const _Vault({required this.balance});
  final int balance;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: SuperPowerDesign.glowShell(radius: 22),
        child: Row(children: [
          const Icon(Icons.account_balance_wallet_rounded, color: SuperPowerDesign.gold, size: 32),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Authority Pool Balance', style: TextStyle(color: SuperPowerDesign.text, fontSize: 12, fontWeight: FontWeight.w900)),
            Text(SuperPowerDesign.compactCoins(balance), style: const TextStyle(color: SuperPowerDesign.gold, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
          ])),
        ]),
      );
}

class _SwitchCommand extends StatelessWidget {
  const _SwitchCommand({required this.title, required this.value, required this.onChanged});
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(11, 6, 6, 6),
        decoration: BoxDecoration(color: SuperPowerDesign.obsidian, borderRadius: BorderRadius.circular(16), border: Border.all(color: SuperPowerDesign.stroke)),
        child: Row(children: [
          Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SuperPowerDesign.text, fontSize: 12.5, fontWeight: FontWeight.w900))),
          Switch.adaptive(value: value, activeThumbColor: SuperPowerDesign.gold, activeTrackColor: const Color(0x55FFD36A), onChanged: onChanged),
        ]),
      );
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(width: 38, height: 38, decoration: BoxDecoration(color: SuperPowerDesign.obsidian, shape: BoxShape.circle, border: Border.all(color: SuperPowerDesign.stroke)), child: Icon(icon, color: SuperPowerDesign.text, size: 21)),
      );
}

class _Denied extends StatelessWidget {
  const _Denied({required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: ControlDeckRow(icon: Icons.lock_rounded, title: 'Protected panel', subtitle: 'Founder/Super Owner or Owner access required', accent: SuperPowerDesign.gold, onTap: onBack),
        ),
      );
}

class _SuperOwnerUserActionDraft {
  const _SuperOwnerUserActionDraft({required this.action, required this.label, required this.userId, required this.reason, required this.resourceType});

  final String action;
  final String label;
  final String userId;
  final String reason;
  final String resourceType;
}

class _SuperOwnerUserActionSheet extends StatefulWidget {
  const _SuperOwnerUserActionSheet();

  static Future<_SuperOwnerUserActionDraft?> show(BuildContext context) {
    return showModalBottomSheet<_SuperOwnerUserActionDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SuperOwnerUserActionSheet(),
    );
  }

  @override
  State<_SuperOwnerUserActionSheet> createState() => _SuperOwnerUserActionSheetState();
}

class _SuperOwnerUserActionSheetState extends State<_SuperOwnerUserActionSheet> {
  final TextEditingController _user = TextEditingController();
  final TextEditingController _reason = TextEditingController();
  final TextEditingController _days = TextEditingController(text: '1');
  String? _selectedDeviceId;
List<String> _deviceIds = const <String>[];
String _action = 'CUSTOM_BAN_DAYS';

static const Map<String, List<String>> _mockUserDevices = <String, List<String>>{
  '1': <String>['web-install-founder-01', 'android-emulator-founder-01', 'edge-browser-founder-01'],
  '2': <String>['web-install-user-02', 'android-device-user-02'],
  '6922022': <String>['web-install-6922022-main', 'edge-browser-6922022', 'android-founder-6922022'],
};

void _loadUserDevices(String userId) {
  final trimmed = userId.trim();
  final devices = _mockUserDevices[trimmed] ??
      <String>[
        'web-install-$trimmed-primary',
        'android-device-$trimmed-last-login',
      ];

  setState(() {
    _deviceIds = devices;
    _selectedDeviceId = devices.isEmpty ? null : devices.first;
  });
}

  @override
  void dispose() {
    _user.dispose();
    _reason.dispose();
    _days.dispose();
    super.dispose();
  }

  void _submit() {
    final userId = _user.text.trim();
    final reason = _reason.text.trim();
    if (userId.isEmpty || reason.isEmpty) return;
    final deviceId = _selectedDeviceId ?? '';
    final days = int.tryParse(_days.text.trim()) ?? 0;
    final label = switch (_action) {
      'CUSTOM_BAN_DAYS' => 'Custom ban',
      'DEVICE_BAN' => 'Device ban',
      'DEVICE_UNBAN' => 'Device unban',
      'BAN_USER' => 'Ban user',
      'UNBAN_USER' => 'Unban user',
      _ => _action,
    };
    final detail = switch (_action) {
      'CUSTOM_BAN_DAYS' => '$days day(s) • $reason',
      'DEVICE_BAN' => 'device_id=${deviceId.isEmpty ? 'not_selected' : deviceId} • $reason',
      'DEVICE_UNBAN' => 'device_id=${deviceId.isEmpty ? 'not_selected' : deviceId} • $reason',
      _ => reason,
    };
    Navigator.pop(
      context,
      _SuperOwnerUserActionDraft(
        action: _action,
        label: label,
        userId: userId,
        reason: detail,
        resourceType: _action == 'DEVICE_BAN' || _action == 'DEVICE_UNBAN' ? 'device_ban' : 'user_ban',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(14, 14, 14, 14 + bottom),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const Text('User Control', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF170D20))),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _action,
              items: const [
                DropdownMenuItem(value: 'CUSTOM_BAN_DAYS', child: Text('Custom ban days')),
                DropdownMenuItem(value: 'DEVICE_BAN', child: Text('Device ban')),
                DropdownMenuItem(value: 'DEVICE_UNBAN', child: Text('Device unban')),
                DropdownMenuItem(value: 'BAN_USER', child: Text('Ban user')),
                DropdownMenuItem(value: 'UNBAN_USER', child: Text('Unban / restore user')),
              ],
              onChanged: (value) => setState(() => _action = value ?? _action),
              decoration: _input('Action'),
            ),
            const SizedBox(height: 8),
            TextField(controller: _user, decoration: _input('Target user ID'), onChanged: _loadUserDevices),
            if (_action == 'CUSTOM_BAN_DAYS') ...[
              const SizedBox(height: 8),
              TextField(controller: _days, keyboardType: TextInputType.number, decoration: _input('No. of ban days')),
            ],
            if (_action == 'DEVICE_BAN' || _action == 'DEVICE_UNBAN') ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedDeviceId,
                items: _deviceIds
                    .map((deviceId) => DropdownMenuItem<String>(
                          value: deviceId,
                          child: Text(deviceId, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _selectedDeviceId = value),
                decoration: _input('Device ID from login history'),
              ),
              const SizedBox(height: 6),
              const Text(
                'Later backend: fetch from /admin/login-history/user/{user_id} or /admin/users/{user_id}/devices.',
                style: TextStyle(color: Color(0xFF6B6474), fontSize: 10.5, fontWeight: FontWeight.w700),
              ),
            ],
            const SizedBox(height: 8),
            TextField(controller: _reason, minLines: 2, maxLines: 3, decoration: _input('Reason')),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, height: 46, child: FilledButton(onPressed: _submit, child: const Text('Apply action'))),
          ]),
        ),
      ),
    );
  }

  InputDecoration _input(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFFAF7F1),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFC99A3B))),
    );
  }
}







