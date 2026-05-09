import 'package:flutter/material.dart';

import 'control_center_models.dart';
import 'control_center_store.dart';

class UltraControlCentrePage extends StatefulWidget {
  const UltraControlCentrePage({super.key, required this.currentRole});

  final String currentRole;

  @override
  State<UltraControlCentrePage> createState() => _UltraControlCentrePageState();
}

class _UltraControlCentrePageState extends State<UltraControlCentrePage> {
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

  Future<void> _save(
    ControlCenterState Function(ControlCenterState state) change, {
    String? action,
    String targetUserId = '-',
    String resourceType = 'control_center',
    String reason = 'Control Centre update',
  }) async {
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

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: _ink, content: Text(text, style: const TextStyle(fontWeight: FontWeight.w800))));
  }

  Future<void> _pool({required bool add}) async {
    final amount = await _NumberSheet.show(context, title: add ? 'Add pool coins' : 'Remove pool coins');
    if (amount == null) return;
    await _save(
      (state) => state.copyWith(coinAuthorityBalance: add ? state.coinAuthorityBalance + amount : (state.coinAuthorityBalance - amount).clamp(0, 1 << 62)),
      action: add ? 'AUTHORITY_POOL_ADDED' : 'AUTHORITY_POOL_REMOVED',
      resourceType: 'authority_pool',
      reason: '$amount coins',
    );
    _toast(add ? 'Pool increased.' : 'Pool reduced.');
  }

  Future<void> _sendCoins() async {
    final draft = await _UserNumberSheet.show(context, title: 'Send coins');
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

  Future<void> _customId() async {
    final draft = await _UserTextSheet.show(context, title: 'Custom ID', label: 'Custom ID');
    if (draft == null) return;
    await _save((state) => state, action: 'CUSTOM_ID_ASSIGNED', targetUserId: draft.userId, resourceType: 'identity', reason: draft.text);
    _toast('Custom ID assigned.');
  }

  Future<void> _userAction(String action) async {
    final draft = await _UserTextSheet.show(context, title: action, label: 'Reason / room ID');
    if (draft == null) return;
    await _save((state) => state, action: action, targetUserId: draft.userId, resourceType: 'user_action', reason: draft.text);
    _toast('$action logged.');
  }

  Future<void> _grantPower() async {
    final draft = await _PowerSheet.show(context);
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

  Future<void> _review(ReviewQueueItem item, String status) async {
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
      backgroundColor: _bg,
      body: SafeArea(
        child: !_allowed
            ? _Denied(onBack: () => Navigator.pop(context))
            : Column(
                children: [
                  _Header(busy: _busy, onBack: () => Navigator.pop(context)),
                  if (state == null)
                    const Expanded(child: Center(child: CircularProgressIndicator(color: _gold)))
                  else
                    Expanded(
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 18),
                        children: [
                          _Tabs(selected: _section, onSelected: (value) => setState(() => _section = value)),
                          const SizedBox(height: 8),
                          if (_section == ControlCenterSection.overview) _Overview(state: state, onAdd: () => _pool(add: true), onRemove: () => _pool(add: false), onSend: _sendCoins, onPower: _grantPower, onCustomId: _customId),
                          if (_section == ControlCenterSection.invisibility) _Stealth(state: state, save: _save),
                          if (_section == ControlCenterSection.economy) _PoolPanel(state: state, onAdd: () => _pool(add: true), onRemove: () => _pool(add: false), onSend: _sendCoins),
                          if (_section == ControlCenterSection.identity) _Identity(onCustomId: _customId),
                          if (_section == ControlCenterSection.powers) _PowerList(state: state, onGrant: _grantPower, onToggle: _togglePower),
                          if (_section == ControlCenterSection.logs) _LogList(state: state),
                          if (_section == ControlCenterSection.review) _ReviewList(state: state, onReview: _review),
                          if (_section == ControlCenterSection.bans) _UserTools(onAction: _userAction),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

const _bg = Color(0xFF06040B);
const _ink = Color(0xFF120A1F);
const _card = Color(0xFF14101D);
const _line = Color(0xFF2B2336);
const _gold = Color(0xFFFFD36A);
const _muted = Color(0xFFA99CB3);

class _Header extends StatelessWidget {
  const _Header({required this.busy, required this.onBack});
  final bool busy;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.only(left: 4, right: 12),
      decoration: const BoxDecoration(color: _ink, border: Border(bottom: BorderSide(color: _line))),
      child: Row(children: [
        IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24)),
        const Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Master Control', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
          Text('Founder / Super Owner', style: TextStyle(color: _muted, fontSize: 10.5, fontWeight: FontWeight.w800)),
        ])),
        if (busy) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: _gold, strokeWidth: 2)),
      ]),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.onSelected});
  final ControlCenterSection selected;
  final ValueChanged<ControlCenterSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 31,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ControlCenterSection.values.length,
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final section = ControlCenterSection.values[index];
          final active = section == selected;
          return InkWell(
            onTap: () => onSelected(section),
            borderRadius: BorderRadius.circular(99),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(color: active ? _gold : _card, borderRadius: BorderRadius.circular(99), border: Border.all(color: active ? _gold : _line)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(section.icon, size: 14, color: active ? _ink : Colors.white),
                const SizedBox(width: 5),
                Text(section.label, style: TextStyle(color: active ? _ink : Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900)),
              ]),
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
  Widget build(BuildContext context) => Column(children: [
        _StatusStrip(state: state),
        const SizedBox(height: 8),
        _TileGrid(tiles: [
          _DashTile('Add Pool', Icons.add_circle_rounded, onAdd),
          _DashTile('Remove', Icons.remove_circle_rounded, onRemove),
          _DashTile('Send Coins', Icons.send_rounded, onSend),
          _DashTile('Power', Icons.admin_panel_settings_rounded, onPower),
          _DashTile('Custom ID', Icons.badge_rounded, onCustomId),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _MiniMetric('Logs', state.logs.length.toString(), Icons.receipt_long_rounded)),
          const SizedBox(width: 8),
          Expanded(child: _MiniMetric('Reviews', state.reviewItems.where((item) => item.status == 'Pending').length.toString(), Icons.fact_check_rounded)),
        ]),
      ]);
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.state});
  final ControlCenterState state;

  @override
  Widget build(BuildContext context) => _Box(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(width: 42, height: 42, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [_gold, Color(0xFFE84C72)])), child: const Icon(Icons.workspace_premium_rounded, color: _ink, size: 23)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Authority Pool', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(_coins(state.coinAuthorityBalance), style: const TextStyle(color: _gold, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.6)),
          ])),
          _TinyPill(state.globalInvisible ? 'INVISIBLE' : 'VISIBLE'),
        ]),
      );
}

class _PoolPanel extends StatelessWidget {
  const _PoolPanel({required this.state, required this.onAdd, required this.onRemove, required this.onSend});
  final ControlCenterState state;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Column(children: [
        _StatusStrip(state: state),
        const SizedBox(height: 8),
        _TileGrid(tiles: [_DashTile('Add Pool', Icons.add_circle_rounded, onAdd), _DashTile('Remove', Icons.remove_circle_rounded, onRemove), _DashTile('Send User', Icons.send_rounded, onSend)]),
        const SizedBox(height: 8),
        const _InfoLine('Super Owner pool can be increased or reduced here. Backend must audit source pool, actor, amount, target and reason.'),
      ]);
}

class _Stealth extends StatelessWidget {
  const _Stealth({required this.state, required this.save});
  final ControlCenterState state;
  final Future<void> Function(ControlCenterState Function(ControlCenterState), {String? action, String targetUserId, String resourceType, String reason}) save;

  @override
  Widget build(BuildContext context) => _SectionBox(title: 'Stealth Presence', children: [
        _SwitchRow('Invisible allover', state.globalInvisible, (v) => save((s) => s.copyWith(globalInvisible: v), action: v ? 'INVISIBILITY_ON' : 'INVISIBILITY_OFF', resourceType: 'presence', reason: 'Global invisibility changed')),
        _SwitchRow('Hide online count', state.hideFromOnlineCount, (v) => save((s) => s.copyWith(hideFromOnlineCount: v), action: 'ONLINE_COUNT_VISIBILITY_CHANGED', resourceType: 'presence', reason: 'Online count changed')),
        _SwitchRow('Hide when seated', state.hideWhenSeated, (v) => save((s) => s.copyWith(hideWhenSeated: v), action: 'SEAT_VISIBILITY_CHANGED', resourceType: 'room_seat', reason: 'Seat visibility changed')),
        _SwitchRow('Hide entry events', state.hideRoomEntryEvents, (v) => save((s) => s.copyWith(hideRoomEntryEvents: v), action: 'ROOM_ENTRY_VISIBILITY_CHANGED', resourceType: 'chat_room', reason: 'Room entry changed')),
        _SwitchRow('Private audit logs', state.auditInvisibleAccess, (v) => save((s) => s.copyWith(auditInvisibleAccess: v), action: 'INVISIBLE_AUDIT_CHANGED', resourceType: 'admin_log', reason: 'Audit setting changed')),
      ]);
}

class _Identity extends StatelessWidget {
  const _Identity({required this.onCustomId});
  final VoidCallback onCustomId;
  @override
  Widget build(BuildContext context) => _SectionBox(title: 'Custom ID Authority', children: [_WideButton('Assign custom ID', Icons.badge_rounded, onCustomId)]);
}

class _PowerList extends StatelessWidget {
  const _PowerList({required this.state, required this.onGrant, required this.onToggle});
  final ControlCenterState state;
  final VoidCallback onGrant;
  final ValueChanged<PowerGrantEntry> onToggle;
  @override
  Widget build(BuildContext context) => _SectionBox(title: 'Power Provider', children: [
        _WideButton('Grant power', Icons.add_moderator_rounded, onGrant),
        const SizedBox(height: 6),
        if (state.powerGrants.isEmpty) const _InfoLine('No power grants yet.') else ...state.powerGrants.map((grant) => _GrantRow(grant: grant, onTap: () => onToggle(grant))),
      ]);
}

class _LogList extends StatelessWidget {
  const _LogList({required this.state});
  final ControlCenterState state;
  @override
  Widget build(BuildContext context) => _SectionBox(title: 'Action Logs', children: state.logs.map((log) => _LogRow(log: log)).toList());
}

class _ReviewList extends StatelessWidget {
  const _ReviewList({required this.state, required this.onReview});
  final ControlCenterState state;
  final Future<void> Function(ReviewQueueItem, String) onReview;
  @override
  Widget build(BuildContext context) => _SectionBox(title: 'Review Queue', children: state.reviewItems.map((item) => _ReviewRow(item: item, onReview: onReview)).toList());
}

class _UserTools extends StatelessWidget {
  const _UserTools({required this.onAction});
  final Future<void> Function(String) onAction;
  @override
  Widget build(BuildContext context) => _TileGrid(tiles: [
        _DashTile('Temp', Icons.timer_rounded, () => onAction('TEMP_BAN_USER')),
        _DashTile('Restrict', Icons.block_rounded, () => onAction('BAN_USER')),
        _DashTile('Permanent', Icons.warning_rounded, () => onAction('PERMANENT_BAN_USER')),
        _DashTile('Restore', Icons.lock_open_rounded, () => onAction('UNBAN_USER')),
      ]);
}

class _Box extends StatelessWidget {
  const _Box({required this.child, this.padding = const EdgeInsets.all(10)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: padding, decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _line)), child: child);
}

class _SectionBox extends StatelessWidget {
  const _SectionBox({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => _Box(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)), const SizedBox(height: 8), ...children]));
}

class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.tiles});
  final List<_DashTile> tiles;
  @override
  Widget build(BuildContext context) => GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: tiles.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 3.15), itemBuilder: (context, index) => tiles[index]);
}

class _DashTile extends StatelessWidget {
  const _DashTile(this.label, this.icon, this.onTap);
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: Container(padding: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _line)), child: Row(children: [Icon(icon, color: _gold, size: 18), const SizedBox(width: 8), Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)))])));
}

class _WideButton extends StatelessWidget {
  const _WideButton(this.label, this.icon, this.onTap);
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: Container(height: 42, padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(gradient: const LinearGradient(colors: [_gold, Color(0xFFC99A3B)]), borderRadius: BorderRadius.circular(14)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: _ink, size: 18), const SizedBox(width: 8), Text(label, style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w900))])));
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => _Box(child: Row(children: [Icon(icon, color: _gold, size: 18), const SizedBox(width: 8), Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)), const SizedBox(width: 5), Expanded(child: Text(label, style: const TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.w800)))]));
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow(this.label, this.value, this.onChanged);
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.only(left: 10), decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(13), border: Border.all(color: _line)), child: Row(children: [Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900))), Switch.adaptive(value: value, activeThumbColor: _gold, activeTrackColor: const Color(0x55FFD36A), onChanged: onChanged)]));
}

class _TinyPill extends StatelessWidget { const _TinyPill(this.label); final String label; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(99), border: Border.all(color: _line)), child: Text(label, style: const TextStyle(color: _gold, fontSize: 9.5, fontWeight: FontWeight.w900))); }
class _InfoLine extends StatelessWidget { const _InfoLine(this.text); final String text; @override Widget build(BuildContext context) => _Box(child: Text(text, style: const TextStyle(color: _muted, fontSize: 11, height: 1.25, fontWeight: FontWeight.w800))); }
class _GrantRow extends StatelessWidget { const _GrantRow({required this.grant, required this.onTap}); final PowerGrantEntry grant; final VoidCallback onTap; @override Widget build(BuildContext context) => _RowShell(child: Row(children: [Expanded(child: Text('${grant.userId} • ${grant.role}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900))), TextButton(onPressed: onTap, child: Text(grant.isActive ? 'Revoke' : 'Restore'))])); }
class _LogRow extends StatelessWidget { const _LogRow({required this.log}); final ControlLogEntry log; @override Widget build(BuildContext context) => _RowShell(child: Text('${log.action}  •  ${log.targetUserId}  •  ${log.reason}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.w800))); }
class _ReviewRow extends StatelessWidget { const _ReviewRow({required this.item, required this.onReview}); final ReviewQueueItem item; final Future<void> Function(ReviewQueueItem, String) onReview; @override Widget build(BuildContext context) => _RowShell(child: Row(children: [Expanded(child: Text('${item.title} • ${item.status}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900))), if (item.status == 'Pending') TextButton(onPressed: () => onReview(item, 'Approved'), child: const Text('Approve'))])); }
class _RowShell extends StatelessWidget { const _RowShell({required this.child}); final Widget child; @override Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(13), border: Border.all(color: _line)), child: child); }
class _Denied extends StatelessWidget { const _Denied({required this.onBack}); final VoidCallback onBack; @override Widget build(BuildContext context) => Center(child: _WideButton('Go back', Icons.arrow_back_rounded, onBack)); }

String _coins(int value) { if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(1)}B'; if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M'; if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K'; return value.toString(); }

class _NumberSheet extends StatefulWidget {
  const _NumberSheet({required this.title});
  final String title;
  static Future<int?> show(BuildContext context, {required String title}) => showModalBottomSheet<int>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => _NumberSheet(title: title));
  @override
  State<_NumberSheet> createState() => _NumberSheetState();
}
class _NumberSheetState extends State<_NumberSheet> { final amount = TextEditingController(); @override void dispose(){amount.dispose(); super.dispose();} @override Widget build(BuildContext context) => _Sheet(title: widget.title, fields: [_field(amount, 'Coin amount', keyboard: TextInputType.number)], onSubmit: () { final parsed = int.tryParse(amount.text.trim()); if (parsed == null || parsed <= 0) return; Navigator.pop(context, parsed); }); }
class _UserNumberDraft { const _UserNumberDraft({required this.userId, required this.amount}); final String userId; final int amount; }
class _UserNumberSheet extends StatefulWidget { const _UserNumberSheet({required this.title}); final String title; static Future<_UserNumberDraft?> show(BuildContext context, {required String title}) => showModalBottomSheet<_UserNumberDraft>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => _UserNumberSheet(title: title)); @override State<_UserNumberSheet> createState() => _UserNumberSheetState(); }
class _UserNumberSheetState extends State<_UserNumberSheet> { final user = TextEditingController(); final amount = TextEditingController(); @override void dispose(){user.dispose(); amount.dispose(); super.dispose();} @override Widget build(BuildContext context) => _Sheet(title: widget.title, fields: [_field(user, 'Target user ID'), _field(amount, 'Coin amount', keyboard: TextInputType.number)], onSubmit: () { final parsed = int.tryParse(amount.text.trim()); if (user.text.trim().isEmpty || parsed == null || parsed <= 0) return; Navigator.pop(context, _UserNumberDraft(userId: user.text.trim(), amount: parsed)); }); }
class _UserTextDraft { const _UserTextDraft({required this.userId, required this.text}); final String userId; final String text; }
class _UserTextSheet extends StatefulWidget { const _UserTextSheet({required this.title, required this.label}); final String title; final String label; static Future<_UserTextDraft?> show(BuildContext context, {required String title, required String label}) => showModalBottomSheet<_UserTextDraft>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => _UserTextSheet(title: title, label: label)); @override State<_UserTextSheet> createState() => _UserTextSheetState(); }
class _UserTextSheetState extends State<_UserTextSheet> { final user = TextEditingController(); final text = TextEditingController(); @override void dispose(){user.dispose(); text.dispose(); super.dispose();} @override Widget build(BuildContext context) => _Sheet(title: widget.title, fields: [_field(user, 'Target user ID'), _field(text, widget.label)], onSubmit: () { if (user.text.trim().isEmpty || text.text.trim().isEmpty) return; Navigator.pop(context, _UserTextDraft(userId: user.text.trim(), text: text.text.trim())); }); }

class _PowerDraft { const _PowerDraft({required this.userId, required this.role, required this.authorities, required this.reason}); final String userId; final String role; final List<String> authorities; final String reason; }
class _PowerSheet extends StatefulWidget { const _PowerSheet(); static Future<_PowerDraft?> show(BuildContext context) => showModalBottomSheet<_PowerDraft>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const _PowerSheet()); @override State<_PowerSheet> createState() => _PowerSheetState(); }
class _PowerSheetState extends State<_PowerSheet> { final user = TextEditingController(); final reason = TextEditingController(); String role = 'monitor'; final selected = <String>{'TEMP_BAN_USER'}; @override void dispose(){user.dispose(); reason.dispose(); super.dispose();} @override Widget build(BuildContext context) => _Sheet(title: 'Grant power', fields: [_field(user, 'Target user ID'), DropdownButtonFormField<String>(initialValue: role, items: controlCenterRoles.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(), onChanged: (value) => setState(() => role = value ?? role), decoration: _input('Role')), const SizedBox(height: 6), Wrap(spacing: 5, runSpacing: 5, children: controlCenterAuthorities.take(8).map((item) => FilterChip(label: Text(item, style: const TextStyle(fontSize: 10)), selected: selected.contains(item), onSelected: (value) => setState(() => value ? selected.add(item) : selected.remove(item)))).toList()), _field(reason, 'Reason')], onSubmit: () { if (user.text.trim().isEmpty || reason.text.trim().isEmpty || selected.isEmpty) return; Navigator.pop(context, _PowerDraft(userId: user.text.trim(), role: role, authorities: selected.toList(), reason: reason.text.trim())); }); }

class _Sheet extends StatelessWidget { const _Sheet({required this.title, required this.fields, required this.onSubmit}); final String title; final List<Widget> fields; final VoidCallback onSubmit; @override Widget build(BuildContext context) { final bottom = MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom; return Container(margin: const EdgeInsets.all(12), padding: EdgeInsets.fromLTRB(14, 14, 14, 14 + bottom), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)), child: SafeArea(top: false, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _ink)), const SizedBox(height: 10), ...fields, SizedBox(width: double.infinity, height: 44, child: FilledButton(onPressed: onSubmit, child: const Text('Submit')))])))); } }
Widget _field(TextEditingController controller, String label, {TextInputType? keyboard}) => Padding(padding: const EdgeInsets.only(bottom: 8), child: TextField(controller: controller, keyboardType: keyboard, decoration: _input(label)));
InputDecoration _input(String label) => InputDecoration(labelText: label, filled: true, fillColor: const Color(0xFFFAF7F1), border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: Color(0xFFECE2D8))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: Color(0xFFECE2D8))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: Color(0xFFC99A3B))));
