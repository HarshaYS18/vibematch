import 'package:flutter/material.dart';

import 'control_center_models.dart';
import 'control_center_store.dart';
import 'widgets/control_action_sheets.dart';
import 'widgets/control_cockpit_overview.dart';
import 'widgets/control_deck_widgets.dart';
import 'widgets/control_performance_panel.dart';
import 'widgets/control_power_categories_panel.dart';
import 'widgets/control_review_panel.dart';
import 'widgets/control_role_panel.dart';
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
    final draft = await ControlUserTextSheet.show(context, title: 'Assign custom ID', label: 'Custom ID');
    if (draft == null) return;
    await _save((state) => state, action: 'CUSTOM_ID_ASSIGNED', targetUserId: draft.userId, resourceType: 'identity', reason: draft.text);
    _toast('Custom ID assigned.');
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
    final draft = await ControlUserTextSheet.show(context, title: action, label: 'Reason / room ID');
    if (draft == null) return;
    await _save((state) => state, action: action, targetUserId: draft.userId, resourceType: 'user_action', reason: draft.text);
    _toast('$action logged.');
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
      ControlCenterSection.overview => ControlCockpitOverview(
          state: state,
          onMint: () => _changePool(add: true),
          onRemovePool: () => _changePool(add: false),
          onSendCoins: _sendCoins,
          onPower: () => setState(() => _section = ControlCenterSection.powers),
          onReview: () => setState(() => _section = ControlCenterSection.review),
          onRole: () => setState(() => _section = ControlCenterSection.powers),
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
      decoration: SuperPowerDesign.glowShell(radius: 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _RoundIcon(icon: Icons.arrow_back_rounded, onTap: onBack),
          const SizedBox(width: 10),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Super Power Panel', style: TextStyle(color: SuperPowerDesign.text, fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -0.6)),
            Text('Founder command deck • role-safe • audit-first', style: TextStyle(color: SuperPowerDesign.muted, fontSize: 11, fontWeight: FontWeight.w800)),
          ])),
          if (busy) const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(color: SuperPowerDesign.gold, strokeWidth: 2)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _ConsoleMetric(label: 'Pool', value: SuperPowerDesign.compactCoins(state.coinAuthorityBalance), icon: Icons.all_inclusive_rounded, color: SuperPowerDesign.gold)),
          const SizedBox(width: 8),
          Expanded(child: _ConsoleMetric(label: 'Stealth', value: state.globalInvisible ? 'ON' : 'OFF', icon: Icons.visibility_off_rounded, color: state.globalInvisible ? SuperPowerDesign.aqua : SuperPowerDesign.muted)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _MiniHeaderPill(icon: Icons.verified_user_rounded, label: '${state.roleAssignments.where((item) => item.isActive).length} roles')),
          const SizedBox(width: 8),
          Expanded(child: _MiniHeaderPill(icon: Icons.fact_check_rounded, label: '${state.reviewItems.where((item) => item.status == 'Pending').length} mapped reviews')),
        ]),
      ]),
    );
  }
}

class _NavDelegate extends SliverPersistentHeaderDelegate {
  _NavDelegate({required this.selected, required this.onSelected});
  final ControlCenterSection selected;
  final ValueChanged<ControlCenterSection> onSelected;

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
        itemCount: ControlCenterSection.values.length,
        separatorBuilder: (context, index) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final item = ControlCenterSection.values[index];
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
          ControlDeckRow(icon: Icons.timer_rounded, title: 'Temporary restriction', subtitle: 'Timed restriction or warning action', accent: SuperPowerDesign.gold, onTap: () => onAction('TEMP_BAN_USER')),
          ControlDeckRow(icon: Icons.block_rounded, title: 'Restrict user', subtitle: 'User restriction with reason', accent: SuperPowerDesign.rose, onTap: () => onAction('BAN_USER')),
          ControlDeckRow(icon: Icons.warning_rounded, title: 'Permanent restriction', subtitle: 'Owner-level permanent action', accent: SuperPowerDesign.rose, onTap: () => onAction('PERMANENT_BAN_USER')),
          ControlDeckRow(icon: Icons.lock_open_rounded, title: 'Restore user', subtitle: 'Restore access / unban action', accent: SuperPowerDesign.aqua, onTap: () => onAction('UNBAN_USER')),
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

class _Logs extends StatelessWidget {
  const _Logs({required this.logs});
  final List<ControlLogEntry> logs;
  @override
  Widget build(BuildContext context) => ControlDeckShell(
        title: 'Audit Stream',
        subtitle: 'Grouped backend-style logs: actor, target, room/resource and reason.',
        trailing: ControlDeckPill(label: '${logs.length} logs'),
        children: logs.map((log) => ControlDeckRow(icon: Icons.receipt_long_rounded, title: log.action, subtitle: '${log.targetUserId} • ${log.resourceType} • ${log.reason}', trailing: ControlDeckPill(label: log.chatRoomId == '-' ? 'LOG' : log.chatRoomId), accent: SuperPowerDesign.gold, onTap: null)).toList(),
      );
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

class _ConsoleMetric extends StatelessWidget {
  const _ConsoleMetric({required this.label, required this.value, required this.icon, required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: SuperPowerDesign.obsidian.withValues(alpha: 0.78), borderRadius: BorderRadius.circular(17), border: Border.all(color: SuperPowerDesign.stroke)),
        child: Row(children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SuperPowerDesign.muted, fontSize: 9.5, fontWeight: FontWeight.w800)),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w900)),
          ])),
        ]),
      );
}

class _MiniHeaderPill extends StatelessWidget {
  const _MiniHeaderPill({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: SuperPowerDesign.obsidian.withValues(alpha: 0.72), borderRadius: BorderRadius.circular(999), border: Border.all(color: SuperPowerDesign.stroke)),
        child: Row(children: [
          Icon(icon, color: SuperPowerDesign.gold, size: 15),
          const SizedBox(width: 6),
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SuperPowerDesign.text, fontSize: 10.5, fontWeight: FontWeight.w800))),
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
