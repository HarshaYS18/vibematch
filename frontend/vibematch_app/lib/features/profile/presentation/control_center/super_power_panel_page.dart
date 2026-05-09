import 'package:flutter/material.dart';

import 'control_center_models.dart';
import 'control_center_store.dart';
import 'widgets/control_action_sheets.dart';
import 'widgets/control_deck_widgets.dart';
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
      (state) => state.copyWith(coinAuthorityBalance: add ? state.coinAuthorityBalance + draft.amount : (state.coinAuthorityBalance - draft.amount).clamp(0, 1 << 62)),
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
      (state) => state.copyWith(powerGrants: <PowerGrantEntry>[
        PowerGrantEntry(id: 'PWR-${DateTime.now().millisecondsSinceEpoch}', userId: draft.userId, role: draft.role, authorities: draft.authorities, reason: draft.reason, isActive: true, createdAt: DateTime.now()),
        ...state.powerGrants,
      ]),
      action: 'POWER_GRANTED',
      targetUserId: draft.userId,
      resourceType: 'special_permission',
      reason: draft.reason,
    );
    _toast('Power granted.');
  }

  Future<void> _togglePower(PowerGrantEntry grant) async {
    await _save(
      (state) => state.copyWith(powerGrants: state.powerGrants.map((item) => item.id == grant.id ? item.copyWith(isActive: !item.isActive) : item).toList()),
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
      (state) => state.copyWith(roleAssignments: <RoleAssignmentEntry>[
        RoleAssignmentEntry(id: 'ROLE-${DateTime.now().millisecondsSinceEpoch}', userId: draft.userId, role: draft.role, assignedByUserId: '6922022', reason: draft.reason, isActive: true, createdAt: DateTime.now()),
        ...state.roleAssignments,
      ]),
      action: 'ROLE_ASSIGNED',
      targetUserId: draft.userId,
      resourceType: 'user_role',
      reason: '${draft.role}: ${draft.reason}',
    );
    _toast('Official role assigned.');
  }

  Future<void> _removeRole(RoleAssignmentEntry role) async {
    await _save(
      (state) => state.copyWith(roleAssignments: state.roleAssignments.map((item) => item.id == role.id ? item.copyWith(isActive: false, removedAt: DateTime.now()) : item).toList()),
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
      (state) => state.copyWith(reviewItems: state.reviewItems.map((entry) => entry.id == item.id ? entry.copyWith(status: status) : entry).toList()),
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
                      SliverPersistentHeader(pinned: true, delegate: _NavDelegate(selected: _section, onSelected: (value) => setState(() => _section = value))),
                      SliverPadding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 24), sliver: SliverToBoxAdapter(child: _body(state))),
                    ],
                  ),
      ),
    );
  }

  Widget _body(ControlCenterState state) {
    return switch (_section) {
      ControlCenterSection.overview => _Overview(state: state, onMint: () => _changePool(add: true), onRemovePool: () => _changePool(add: false), onSendCoins: _sendCoins, onPower: () => setState(() => _section = ControlCenterSection.powers), onReview: () => setState(() => _section = ControlCenterSection.review), onRole: () => setState(() => _section = ControlCenterSection.powers)),
      ControlCenterSection.invisibility => _Stealth(state: state, save: _save),
      ControlCenterSection.logs => _Logs(logs: state.logs),
      ControlCenterSection.powers => Column(children: [ControlRolePanel(roles: state.roleAssignments, onAssignRole: _assignRole, onRemoveRole: _removeRole), const SizedBox(height: 12), ControlPowerCategoriesPanel(grants: state.powerGrants, onGrantPower: _grantPower, onToggleGrant: _togglePower)]),
      ControlCenterSection.bans => _UserAuthority(onAction: _userAction),
      ControlCenterSection.review => ControlReviewPanel(items: state.reviewItems, onApprove: (item) => _review(item, 'Approved'), onReject: (item) => _review(item, 'Rejected')),
      ControlCenterSection.economy => _Economy(state: state, onMint: () => _changePool(add: true), onRemovePool: () => _changePool(add: false), onSendCoins: _sendCoins),
      ControlCenterSection.identity => _Identity(onAssignCustomId: _assignCustomId),
    };
  }
}
