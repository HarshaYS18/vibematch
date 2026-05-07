import 'package:flutter/material.dart';

import 'control_center_models.dart';
import 'control_center_store.dart';

class PremiumControlCentrePage extends StatefulWidget {
  const PremiumControlCentrePage({super.key, required this.currentRole});

  final String currentRole;

  @override
  State<PremiumControlCentrePage> createState() => _PremiumControlCentrePageState();
}

class _PremiumControlCentrePageState extends State<PremiumControlCentrePage> {
  ControlCenterState? _state;
  ControlCenterSection _section = ControlCenterSection.overview;
  bool _busy = false;

  bool get _canOpen {
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

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF090510), content: Text(text, style: const TextStyle(fontWeight: FontWeight.w800))));
  }

  Future<void> _save(ControlCenterState Function(ControlCenterState state) change, {String? action, String targetUserId = '-', String resourceType = 'control_center', String reason = 'Control Centre update'}) async {
    final current = _state;
    if (current == null || _busy) return;
    setState(() => _busy = true);
    var next = change(current);
    if (action == null) {
      await ControlCenterStore.save(next);
    } else {
      next = await ControlCenterStore.writeLog(next, action: action, targetUserId: targetUserId, chatRoomId: '-', resourceType: resourceType, reason: reason);
    }
    if (!mounted) return;
    setState(() {
      _state = next;
      _busy = false;
    });
  }

  Future<void> _changePool({required bool add}) async {
    final amount = await _AmountSheet.show(context, title: add ? 'Add authority pool coins' : 'Remove authority pool coins');
    if (amount == null) return;
    await _save(
      (state) => state.copyWith(
        coinAuthorityBalance: add ? state.coinAuthorityBalance + amount : (state.coinAuthorityBalance - amount).clamp(0, 1 << 62),
      ),
      action: add ? 'AUTHORITY_POOL_ADDED' : 'AUTHORITY_POOL_REMOVED',
      resourceType: 'authority_pool',
      reason: '$amount coins',
    );
    _toast(add ? 'Authority pool increased.' : 'Authority pool reduced.');
  }

  Future<void> _sendCoins() async {
    final draft = await _TargetAmountSheet.show(context, title: 'Send coins to user');
    if (draft == null) return;
    await _save(
      (state) => state.copyWith(coinAuthorityBalance: (state.coinAuthorityBalance - draft.amount).clamp(0, 1 << 62)),
      action: 'COINS_SENT',
      targetUserId: draft.userId,
      resourceType: 'wallet',
      reason: '${draft.amount} coins',
    );
    _toast('Coins sent to ${draft.userId}.');
  }

  Future<void> _customId() async {
    final draft = await _TargetTextSheet.show(context, title: 'Assign custom ID', textLabel: 'Custom ID');
    if (draft == null) return;
    await _save((state) => state, action: 'CUSTOM_ID_ASSIGNED', targetUserId: draft.userId, resourceType: 'identity', reason: draft.text);
    _toast('Custom ID assigned.');
  }

  Future<void> _grantPower() async {
    final draft = await _PowerSheet.show(context);
    if (draft == null) return;
    await _save(
      (state) => state.copyWith(
        powerGrants: <PowerGrantEntry>[
          PowerGrantEntry(id: 'PWR-${DateTime.now().millisecondsSinceEpoch}', userId: draft.userId, role: draft.role, authorities: draft.authorities, reason: draft.reason, isActive: true, createdAt: DateTime.now()),
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

  Future<void> _toggleGrant(PowerGrantEntry grant) async {
    await _save(
      (state) => state.copyWith(powerGrants: state.powerGrants.map((item) => item.id == grant.id ? item.copyWith(isActive: !item.isActive) : item).toList()),
      action: grant.isActive ? 'POWER_REVOKED' : 'POWER_RESTORED',
      targetUserId: grant.userId,
      resourceType: 'special_permission',
      reason: grant.reason,
    );
  }

  Future<void> _userAction(String title, String action) async {
    final draft = await _TargetTextSheet.show(context, title: title, textLabel: 'Reason / room ID');
    if (draft == null) return;
    await _save((state) => state, action: action, targetUserId: draft.userId, resourceType: 'user_action', reason: draft.text);
    _toast('$title logged.');
  }

  Future<void> _reviewItem(ReviewQueueItem item, String status) async {
    await _save(
      (state) => state.copyWith(reviewItems: state.reviewItems.map((entry) => entry.id == item.id ? entry.copyWith(status: status) : entry).toList()),
      action: 'REVIEW_${status.toUpperCase()}',
      targetUserId: item.userId,
      resourceType: item.type,
      reason: item.title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    return Scaffold(
      backgroundColor: const Color(0xFF07040D),
      body: SafeArea(
        child: !_canOpen
            ? _Denied(onBack: () => Navigator.pop(context))
            : Column(
                children: [
                  _Header(busy: _busy, onBack: () => Navigator.pop(context)),
                  if (state == null)
                    const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFFFFD36A))))
                  else
                    Expanded(
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                        children: [
                          _SectionTabs(selected: _section, onSelected: (value) => setState(() => _section = value)),
                          const SizedBox(height: 10),
                          if (_section == ControlCenterSection.overview) _Overview(state: state, onAdd: () => _changePool(add: true), onRemove: () => _changePool(add: false), onSend: _sendCoins, onPower: _grantPower, onCustomId: _customId),
                          if (_section == ControlCenterSection.invisibility) _Invisibility(state: state, onSave: _save),
                          if (_section == ControlCenterSection.economy) _Economy(state: state, onAdd: () => _changePool(add: true), onRemove: () => _changePool(add: false), onSend: _sendCoins),
                          if (_section == ControlCenterSection.identity) _Identity(onCustomId: _customId),
                          if (_section == ControlCenterSection.powers) _Powers(state: state, onGrant: _grantPower, onToggle: _toggleGrant),
                          if (_section == ControlCenterSection.logs) _Logs(state: state),
                          if (_section == ControlCenterSection.review) _Reviews(state: state, onReview: _reviewItem),
                          if (_section == ControlCenterSection.bans) _UserActions(onAction: _userAction),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.busy, required this.onBack});
  final bool busy;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.055), border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)))),
      child: Row(children: [
        IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 27)),
        const Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Master Control', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.4)), Text('Premium Super Owner panel', style: TextStyle(color: Color(0xFFAFA3B8), fontSize: 11, fontWeight: FontWeight.w800))])),
        if (busy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Color(0xFFFFD36A), strokeWidth: 2.2)),
      ]),
    );
  }
}

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({required this.selected, required this.onSelected});
  final ControlCenterSection selected;
  final ValueChanged<ControlCenterSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ControlCenterSection.values.length,
        separatorBuilder: (context, index) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final section = ControlCenterSection.values[index];
          final active = section == selected;
          return InkWell(
            onTap: () => onSelected(section),
            borderRadius: BorderRadius.circular(99),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(color: active ? const Color(0xFFFFD36A) : Colors.white.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(99), border: Border.all(color: active ? const Color(0xFFFFD36A) : Colors.white.withValues(alpha: 0.08))),
              child: Row(children: [Icon(section.icon, size: 15, color: active ? const Color(0xFF170D20) : Colors.white), const SizedBox(width: 5), Text(section.label, style: TextStyle(color: active ? const Color(0xFF170D20) : Colors.white, fontSize: 11, fontWeight: FontWeight.w900))]),
            ),
          );
        },
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.state, required this.onAdd, required this.onRemove, required this.onSend, required this.onPower, required this.onCustomId});
  final ControlCenterState state;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onSend;
  final VoidCallback onPower;
  final VoidCallback onCustomId;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _Hero(state: state),
      const SizedBox(height: 10),
      _Metrics(state: state),
      const SizedBox(height: 10),
      _QuickGrid(actions: [_Quick('Add Pool', Icons.add_circle_rounded, onAdd), _Quick('Remove Pool', Icons.remove_circle_rounded, onRemove), _Quick('Send Coins', Icons.send_rounded, onSend), _Quick('Grant Power', Icons.admin_panel_settings_rounded, onPower), _Quick('Custom ID', Icons.badge_rounded, onCustomId)]),
    ]);
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.state});
  final ControlCenterState state;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 48, height: 48, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFFFFD36A), Color(0xFFE84C72)])), child: const Icon(Icons.workspace_premium_rounded, color: Colors.white)),
          const SizedBox(width: 11),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Founder Authority', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)), Text('Compact protected master tools', style: TextStyle(color: Color(0xFFAFA3B8), fontSize: 11, fontWeight: FontWeight.w800))])),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 7, runSpacing: 7, children: [_Pill('Pool ${_coins(state.coinAuthorityBalance)}'), _Pill(state.globalInvisible ? 'Invisible ON' : 'Visible'), _Pill('${state.powerGrants.where((g) => g.isActive).length} powers')]),
      ]),
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.state});
  final ControlCenterState state;

  @override
  Widget build(BuildContext context) {
    return GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, childAspectRatio: 1.65, mainAxisSpacing: 8, crossAxisSpacing: 8, children: [_Metric('Pool', _coins(state.coinAuthorityBalance), Icons.account_balance_wallet_rounded), _Metric('Invisible', state.globalInvisible ? 'ON' : 'OFF', Icons.visibility_off_rounded), _Metric('Logs', state.logs.length.toString(), Icons.receipt_long_rounded), _Metric('Reviews', state.reviewItems.where((item) => item.status == 'Pending').length.toString(), Icons.fact_check_rounded)]);
  }
}

class _Invisibility extends StatelessWidget {
  const _Invisibility({required this.state, required this.onSave});
  final ControlCenterState state;
  final Future<void> Function(ControlCenterState Function(ControlCenterState), {String? action, String targetUserId, String resourceType, String reason}) onSave;

  @override
  Widget build(BuildContext context) {
    return _ListPanel(title: 'Stealth Presence', subtitle: 'Hide allover the app, including online count and seated state.', children: [
      _SwitchLine('Invisible allover app', 'Hide public presence everywhere.', state.globalInvisible, (v) => onSave((s) => s.copyWith(globalInvisible: v), action: v ? 'INVISIBILITY_ON' : 'INVISIBILITY_OFF', resourceType: 'presence', reason: 'Global invisibility changed')),
      _SwitchLine('Hide from online count', 'Counters must not include Super Owner.', state.hideFromOnlineCount, (v) => onSave((s) => s.copyWith(hideFromOnlineCount: v), action: 'ONLINE_COUNT_VISIBILITY_CHANGED', resourceType: 'presence', reason: 'Online counter visibility changed')),
      _SwitchLine('Hide even when seated', 'Seat should not publicly reveal Super Owner.', state.hideWhenSeated, (v) => onSave((s) => s.copyWith(hideWhenSeated: v), action: 'SEAT_VISIBILITY_CHANGED', resourceType: 'room_seat', reason: 'Seat visibility changed')),
      _SwitchLine('Hide entry events', 'No room enter message or public activity trail.', state.hideRoomEntryEvents, (v) => onSave((s) => s.copyWith(hideRoomEntryEvents: v), action: 'ROOM_ENTRY_VISIBILITY_CHANGED', resourceType: 'chat_room', reason: 'Entry visibility changed')),
      _SwitchLine('Private audit logs', 'Backend still logs invisible access privately.', state.auditInvisibleAccess, (v) => onSave((s) => s.copyWith(auditInvisibleAccess: v), action: 'INVISIBLE_AUDIT_CHANGED', resourceType: 'admin_log', reason: 'Invisible audit changed')),
    ]);
  }
}

class _Economy extends StatelessWidget {
  const _Economy({required this.state, required this.onAdd, required this.onRemove, required this.onSend});
  final ControlCenterState state;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _Panel(child: Row(children: [const Icon(Icons.all_inclusive_rounded, color: Color(0xFFFFD36A), size: 30), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Authority Pool', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)), Text('${_coins(state.coinAuthorityBalance)} coins available', style: const TextStyle(color: Color(0xFFAFA3B8), fontWeight: FontWeight.w800, fontSize: 12))]))])),
      const SizedBox(height: 10),
      _QuickGrid(actions: [_Quick('Add Coins', Icons.add_circle_rounded, onAdd), _Quick('Remove Coins', Icons.remove_circle_rounded, onRemove), _Quick('Send User', Icons.send_rounded, onSend)]),
      const SizedBox(height: 10),
      const _Note('Super Owner authority pool can be topped up or reduced here. Backend should audit source pool, actor, amount and reason.'),
    ]);
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.onCustomId});
  final VoidCallback onCustomId;

  @override
  Widget build(BuildContext context) => _ListPanel(title: 'Custom ID', subtitle: 'Assign protected custom IDs to any user.', children: [_ActionButton('Assign custom ID', Icons.badge_rounded, onCustomId)]);
}

class _Powers extends StatelessWidget {
  const _Powers({required this.state, required this.onGrant, required this.onToggle});
  final ControlCenterState state;
  final VoidCallback onGrant;
  final ValueChanged<PowerGrantEntry> onToggle;

  @override
  Widget build(BuildContext context) => _ListPanel(title: 'Power Provider', subtitle: 'Grant or revoke role-level authorities.', children: [_ActionButton('Grant power', Icons.add_moderator_rounded, onGrant), const SizedBox(height: 8), if (state.powerGrants.isEmpty) const _Note('No power grants yet.') else ...state.powerGrants.map((grant) => _GrantCard(grant: grant, onTap: () => onToggle(grant)))]);
}

class _Logs extends StatelessWidget {
  const _Logs({required this.state});
  final ControlCenterState state;

  @override
  Widget build(BuildContext context) => _ListPanel(title: 'Grouped Logs', subtitle: 'Recent actions by user, room and resource.', children: state.logs.map((log) => _LogCard(log)).toList());
}

class _Reviews extends StatelessWidget {
  const _Reviews({required this.state, required this.onReview});
  final ControlCenterState state;
  final Future<void> Function(ReviewQueueItem, String) onReview;

  @override
  Widget build(BuildContext context) => _ListPanel(title: 'Review Panel', subtitle: 'CS escalations, reports, DP and custom asset reviews.', children: state.reviewItems.map((item) => _ReviewCard(item: item, onApprove: () => onReview(item, 'Approved'), onReject: () => onReview(item, 'Rejected'))).toList());
}

class _UserActions extends StatelessWidget {
  const _UserActions({required this.onAction});
  final Future<void> Function(String, String) onAction;

  @override
  Widget build(BuildContext context) => _ListPanel(title: 'User Authority', subtitle: 'Owner-level user action controls with logs.', children: [_QuickGrid(actions: [_Quick('Temp Action', Icons.timer_rounded, () => onAction('Temporary action', 'TEMP_BAN_USER')), _Quick('Restrict', Icons.block_rounded, () => onAction('User action', 'BAN_USER')), _Quick('Permanent', Icons.warning_rounded, () => onAction('Permanent action', 'PERMANENT_BAN_USER')), _Quick('Restore', Icons.lock_open_rounded, () => onAction('Restore user', 'UNBAN_USER'))])]);
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: _decoration(), child: child);
}

class _ListPanel extends StatelessWidget {
  const _ListPanel({required this.title, required this.subtitle, required this.children});
  final String title;
  final String subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: Color(0xFFAFA3B8), fontSize: 11.5, height: 1.25, fontWeight: FontWeight.w800)), const SizedBox(height: 10), ...children]));
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => _Panel(child: Row(children: [Icon(icon, color: const Color(0xFFFFD36A), size: 22), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(color: Color(0xFFAFA3B8), fontSize: 10.5, fontWeight: FontWeight.w800))]))]));
}

class _Quick {
  const _Quick(this.title, this.icon, this.onTap);
  final String title;
  final IconData icon;
  final VoidCallback onTap;
}

class _QuickGrid extends StatelessWidget {
  const _QuickGrid({required this.actions});
  final List<_Quick> actions;
  @override
  Widget build(BuildContext context) => GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: actions.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 2.65), itemBuilder: (_, index) { final action = actions[index]; return _ActionButton(action.title, action.icon, action.onTap); });
}

class _ActionButton extends StatelessWidget {
  const _ActionButton(this.label, this.icon, this.onTap);
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(15), child: Container(alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 9), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFFD36A), Color(0xFFC99A3B)]), borderRadius: BorderRadius.circular(15)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 17, color: const Color(0xFF170D20)), const SizedBox(width: 6), Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF170D20), fontWeight: FontWeight.w900, fontSize: 11.5)))])));
}

class _SwitchLine extends StatelessWidget {
  const _SwitchLine(this.title, this.subtitle, this.value, this.onChanged);
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 7), padding: const EdgeInsets.fromLTRB(11, 8, 8, 8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.055), borderRadius: BorderRadius.circular(16)), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)), Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFAFA3B8), fontSize: 10.5, height: 1.2, fontWeight: FontWeight.w700))])), Switch.adaptive(value: value, activeThumbColor: const Color(0xFFFFD36A), activeTrackColor: const Color(0x55FFD36A), onChanged: onChanged)]));
}

class _Pill extends StatelessWidget { const _Pill(this.text); final String text; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white.withValues(alpha: 0.08))), child: Text(text, style: const TextStyle(color: Color(0xFFFFD36A), fontSize: 10.5, fontWeight: FontWeight.w900))); }
class _Note extends StatelessWidget { const _Note(this.text); final String text; @override Widget build(BuildContext context) => _Panel(child: Text(text, style: const TextStyle(color: Color(0xFFAFA3B8), fontSize: 11.5, height: 1.3, fontWeight: FontWeight.w800))); }
class _LogCard extends StatelessWidget { const _LogCard(this.log); final ControlLogEntry log; @override Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.055), borderRadius: BorderRadius.circular(15)), child: Text('${log.action} - ${log.targetUserId} - ${log.reason}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFAFA3B8), fontSize: 11, fontWeight: FontWeight.w800))); }
class _GrantCard extends StatelessWidget { const _GrantCard({required this.grant, required this.onTap}); final PowerGrantEntry grant; final VoidCallback onTap; @override Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.055), borderRadius: BorderRadius.circular(15)), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${grant.userId} - ${grant.role}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)), Text(grant.authorities.join(', '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFAFA3B8), fontSize: 10.5, fontWeight: FontWeight.w700))])), TextButton(onPressed: onTap, child: Text(grant.isActive ? 'Revoke' : 'Restore'))])); }
class _ReviewCard extends StatelessWidget { const _ReviewCard({required this.item, required this.onApprove, required this.onReject}); final ReviewQueueItem item; final VoidCallback onApprove; final VoidCallback onReject; @override Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.055), borderRadius: BorderRadius.circular(15)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)), Text('${item.type} - ${item.userId} - ${item.status}', style: const TextStyle(color: Color(0xFFAFA3B8), fontSize: 10.5, fontWeight: FontWeight.w700)), if (item.status == 'Pending') Padding(padding: const EdgeInsets.only(top: 7), child: Row(children: [Expanded(child: OutlinedButton(onPressed: onReject, child: const Text('Reject'))), const SizedBox(width: 8), Expanded(child: FilledButton(onPressed: onApprove, child: const Text('Approve')))]))])); }
class _Denied extends StatelessWidget { const _Denied({required this.onBack}); final VoidCallback onBack; @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(22), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.lock_rounded, color: Color(0xFFFFD36A), size: 50), const SizedBox(height: 10), const Text('Protected panel', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)), const SizedBox(height: 8), const Text('Only Founder/Super Owner or Owner roles can open this Control Centre.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFAFA3B8), fontWeight: FontWeight.w700)), const SizedBox(height: 14), _ActionButton('Go back', Icons.arrow_back_rounded, onBack)]))); }

BoxDecoration _decoration() => BoxDecoration(color: Colors.white.withValues(alpha: 0.075), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.085)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 14, offset: const Offset(0, 7))]);
String _coins(int value) { if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(1)}B'; if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M'; if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K'; return value.toString(); }

class _AmountSheet extends StatefulWidget {
  const _AmountSheet({required this.title});
  final String title;
  static Future<int?> show(BuildContext context, {required String title}) => showModalBottomSheet<int>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => _AmountSheet(title: title));
  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}
class _AmountSheetState extends State<_AmountSheet> { final amount = TextEditingController(); @override void dispose(){amount.dispose(); super.dispose();} @override Widget build(BuildContext context) => _Sheet(title: widget.title, fields: [_field(amount, 'Coin amount', keyboard: TextInputType.number)], onSubmit: () { final parsed = int.tryParse(amount.text.trim()); if (parsed == null || parsed <= 0) return; Navigator.pop(context, parsed); }); }
class _TargetAmountDraft { const _TargetAmountDraft({required this.userId, required this.amount}); final String userId; final int amount; }
class _TargetAmountSheet extends StatefulWidget { const _TargetAmountSheet({required this.title}); final String title; static Future<_TargetAmountDraft?> show(BuildContext context, {required String title}) => showModalBottomSheet<_TargetAmountDraft>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => _TargetAmountSheet(title: title)); @override State<_TargetAmountSheet> createState() => _TargetAmountSheetState(); }
class _TargetAmountSheetState extends State<_TargetAmountSheet> { final user = TextEditingController(); final amount = TextEditingController(); @override void dispose(){user.dispose(); amount.dispose(); super.dispose();} @override Widget build(BuildContext context) => _Sheet(title: widget.title, fields: [_field(user, 'Target user ID'), _field(amount, 'Coin amount', keyboard: TextInputType.number)], onSubmit: () { final parsed = int.tryParse(amount.text.trim()); if (user.text.trim().isEmpty || parsed == null || parsed <= 0) return; Navigator.pop(context, _TargetAmountDraft(userId: user.text.trim(), amount: parsed)); }); }
class _TargetTextDraft { const _TargetTextDraft({required this.userId, required this.text}); final String userId; final String text; }
class _TargetTextSheet extends StatefulWidget { const _TargetTextSheet({required this.title, required this.textLabel}); final String title; final String textLabel; static Future<_TargetTextDraft?> show(BuildContext context, {required String title, required String textLabel}) => showModalBottomSheet<_TargetTextDraft>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => _TargetTextSheet(title: title, textLabel: textLabel)); @override State<_TargetTextSheet> createState() => _TargetTextSheetState(); }
class _TargetTextSheetState extends State<_TargetTextSheet> { final user = TextEditingController(); final text = TextEditingController(); @override void dispose(){user.dispose(); text.dispose(); super.dispose();} @override Widget build(BuildContext context) => _Sheet(title: widget.title, fields: [_field(user, 'Target user ID'), _field(text, widget.textLabel)], onSubmit: () { if (user.text.trim().isEmpty || text.text.trim().isEmpty) return; Navigator.pop(context, _TargetTextDraft(userId: user.text.trim(), text: text.text.trim())); }); }
class _PowerDraft { const _PowerDraft({required this.userId, required this.role, required this.authorities, required this.reason}); final String userId; final String role; final List<String> authorities; final String reason; }
class _PowerSheet extends StatefulWidget { const _PowerSheet(); static Future<_PowerDraft?> show(BuildContext context) => showModalBottomSheet<_PowerDraft>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const _PowerSheet()); @override State<_PowerSheet> createState() => _PowerSheetState(); }
class _PowerSheetState extends State<_PowerSheet> { final user = TextEditingController(); final reason = TextEditingController(); String role = 'monitor'; final selected = <String>{'TEMP_BAN_USER'}; @override void dispose(){user.dispose(); reason.dispose(); super.dispose();} @override Widget build(BuildContext context) => _Sheet(title: 'Grant power', fields: [_field(user, 'Target user ID'), DropdownButtonFormField<String>(initialValue: role, items: controlCenterRoles.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(), onChanged: (value) => setState(() => role = value ?? role), decoration: _input('Role')), const SizedBox(height: 8), Wrap(spacing: 6, runSpacing: 6, children: controlCenterAuthorities.map((item) => FilterChip(label: Text(item), selected: selected.contains(item), onSelected: (value) => setState(() => value ? selected.add(item) : selected.remove(item)))).toList()), _field(reason, 'Reason')], onSubmit: () { if (user.text.trim().isEmpty || reason.text.trim().isEmpty || selected.isEmpty) return; Navigator.pop(context, _PowerDraft(userId: user.text.trim(), role: role, authorities: selected.toList(), reason: reason.text.trim())); }); }
class _Sheet extends StatelessWidget { const _Sheet({required this.title, required this.fields, required this.onSubmit}); final String title; final List<Widget> fields; final VoidCallback onSubmit; @override Widget build(BuildContext context) { final bottom = MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom; return Container(margin: const EdgeInsets.all(14), padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26)), child: SafeArea(top: false, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF170D20))), const SizedBox(height: 12), ...fields, const SizedBox(height: 10), SizedBox(width: double.infinity, height: 48, child: FilledButton(onPressed: onSubmit, child: const Text('Submit')))])))); } }
Widget _field(TextEditingController controller, String label, {TextInputType? keyboard}) => Padding(padding: const EdgeInsets.only(bottom: 9), child: TextField(controller: controller, keyboardType: keyboard, decoration: _input(label)));
InputDecoration _input(String label) => InputDecoration(labelText: label, filled: true, fillColor: const Color(0xFFFAF7F1), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFFECE2D8))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFFECE2D8))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFFC99A3B))));
