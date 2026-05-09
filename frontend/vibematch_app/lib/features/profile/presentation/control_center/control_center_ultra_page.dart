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
    String roomId = '-',
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
      next = await ControlCenterStore.writeLog(
        next,
        action: action,
        targetUserId: targetUserId,
        chatRoomId: roomId,
        resourceType: resourceType,
        reason: reason,
      );
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
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: _obsidian, content: Text(text, style: const TextStyle(fontWeight: FontWeight.w800))));
  }

  Future<void> _pool({required bool add}) async {
    final amount = await _NumberSheet.show(context, title: add ? 'Mint into authority pool' : 'Remove from authority pool');
    if (amount == null) return;
    await _save(
      (state) => state.copyWith(coinAuthorityBalance: add ? state.coinAuthorityBalance + amount : (state.coinAuthorityBalance - amount).clamp(0, 1 << 62)),
      action: add ? 'AUTHORITY_POOL_MINTED' : 'AUTHORITY_POOL_REMOVED',
      resourceType: 'authority_pool',
      reason: '$amount coins',
    );
    _toast(add ? 'Authority pool minted.' : 'Authority pool reduced.');
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
    final draft = await _UserTextSheet.show(context, title: 'Assign custom ID', label: 'Custom ID');
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
      roomId: item.roomId,
      resourceType: item.type,
      reason: item.title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    return Scaffold(
      backgroundColor: _voidBlack,
      body: SafeArea(
        child: !_allowed
            ? _Denied(onBack: () => Navigator.pop(context))
            : state == null
                ? const Center(child: CircularProgressIndicator(color: _royalGold))
                : CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _CommandHeader(state: state, busy: _busy, onBack: () => Navigator.pop(context))),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _PinnedNavDelegate(
                          selected: _section,
                          onSelected: (value) => setState(() => _section = value),
                        ),
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
      ControlCenterSection.overview => _OverviewDeck(
          state: state,
          onMint: () => _pool(add: true),
          onRemove: () => _pool(add: false),
          onSend: _sendCoins,
          onPower: _grantPower,
          onCustomId: _customId,
          onModerate: () => setState(() => _section = ControlCenterSection.bans),
        ),
      ControlCenterSection.invisibility => _StealthDeck(state: state, save: _save),
      ControlCenterSection.logs => _LogsDeck(state: state),
      ControlCenterSection.powers => _PowersDeck(state: state, onGrant: _grantPower, onToggle: _togglePower),
      ControlCenterSection.bans => _ModerationDeck(onAction: _userAction),
      ControlCenterSection.review => _ReviewDeck(state: state, onReview: _review),
      ControlCenterSection.economy => _EconomyDeck(state: state, onMint: () => _pool(add: true), onRemove: () => _pool(add: false), onSend: _sendCoins),
      ControlCenterSection.identity => _IdentityDeck(onCustomId: _customId),
    };
  }
}

const _voidBlack = Color(0xFF050309);
const _obsidian = Color(0xFF0D0715);
const _panel = Color(0xFF14101C);
const _panel2 = Color(0xFF1A1324);
const _line = Color(0xFF32283D);
const _royalGold = Color(0xFFFFD36A);
const _rose = Color(0xFFFF5D8F);
const _violet = Color(0xFF8A5CFF);
const _aqua = Color(0xFF45E5FF);
const _muted = Color(0xFFB0A5BC);

class _CommandHeader extends StatelessWidget {
  const _CommandHeader({required this.state, required this.busy, required this.onBack});
  final ControlCenterState state;
  final bool busy;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF21142F), Color(0xFF09050F)]),
        border: Border.all(color: const Color(0x55FFD36A)),
        boxShadow: [BoxShadow(color: _royalGold.withValues(alpha: 0.10), blurRadius: 28, offset: const Offset(0, 14))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _RoundIcon(icon: Icons.arrow_back_rounded, onTap: onBack),
          const SizedBox(width: 10),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Vibe Match OS', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.6)),
            Text('Founder command deck', style: TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.w800)),
          ])),
          if (busy) const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(color: _royalGold, strokeWidth: 2)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _ConsoleValue(label: 'Authority Pool', value: _coins(state.coinAuthorityBalance), icon: Icons.all_inclusive_rounded, color: _royalGold)),
          const SizedBox(width: 8),
          Expanded(child: _ConsoleValue(label: 'Stealth', value: state.globalInvisible ? 'ON' : 'OFF', icon: Icons.visibility_off_rounded, color: state.globalInvisible ? _aqua : _muted)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _SmallChip(icon: Icons.admin_panel_settings_rounded, label: '${state.powerGrants.where((item) => item.isActive).length} active powers')),
          const SizedBox(width: 8),
          Expanded(child: _SmallChip(icon: Icons.fact_check_rounded, label: '${state.reviewItems.where((item) => item.status == 'Pending').length} pending reviews')),
        ]),
      ]),
    );
  }
}

class _PinnedNavDelegate extends SliverPersistentHeaderDelegate {
  _PinnedNavDelegate({required this.selected, required this.onSelected});
  final ControlCenterSection selected;
  final ValueChanged<ControlCenterSection> onSelected;

  @override
  double get minExtent => 50;
  @override
  double get maxExtent => 50;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: _voidBlack,
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ControlCenterSection.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final item = ControlCenterSection.values[index];
          final active = selected == item;
          return InkWell(
            onTap: () => onSelected(item),
            borderRadius: BorderRadius.circular(999),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: active ? _royalGold : _panel,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: active ? _royalGold : _line),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(item.icon, size: 15, color: active ? _obsidian : Colors.white),
                const SizedBox(width: 6),
                Text(item.label, style: TextStyle(color: active ? _obsidian : Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
              ]),
            ),
          );
        },
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedNavDelegate oldDelegate) => oldDelegate.selected != selected;
}

class _OverviewDeck extends StatelessWidget {
  const _OverviewDeck({required this.state, required this.onMint, required this.onRemove, required this.onSend, required this.onPower, required this.onCustomId, required this.onModerate});
  final ControlCenterState state;
  final VoidCallback onMint;
  final VoidCallback onRemove;
  final VoidCallback onSend;
  final VoidCallback onPower;
  final VoidCallback onCustomId;
  final VoidCallback onModerate;

  @override
  Widget build(BuildContext context) => Column(children: [
        _CommandGroup(title: 'Instant Commands', children: [
          _CommandRow(icon: Icons.add_circle_rounded, title: 'Mint authority pool', subtitle: 'Add unlimited founder coins', accent: _royalGold, onTap: onMint),
          _CommandRow(icon: Icons.remove_circle_rounded, title: 'Remove pool coins', subtitle: 'Reduce authority balance', accent: _rose, onTap: onRemove),
          _CommandRow(icon: Icons.send_rounded, title: 'Send coins to user', subtitle: 'Transfer from pool with audit log', accent: _aqua, onTap: onSend),
          _CommandRow(icon: Icons.admin_panel_settings_rounded, title: 'Power provider', subtitle: 'Grant role authority safely', accent: _violet, onTap: onPower),
          _CommandRow(icon: Icons.badge_rounded, title: 'Assign custom ID', subtitle: 'Premium ID authority', accent: _royalGold, onTap: onCustomId),
          _CommandRow(icon: Icons.gavel_rounded, title: 'User authority tools', subtitle: 'Restrict, restore and log actions', accent: _rose, onTap: onModerate),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _MetricMini(label: 'Logs', value: state.logs.length.toString(), icon: Icons.receipt_long_rounded)),
          const SizedBox(width: 8),
          Expanded(child: _MetricMini(label: 'Reviews', value: state.reviewItems.where((item) => item.status == 'Pending').length.toString(), icon: Icons.fact_check_rounded)),
        ]),
      ]);
}

class _EconomyDeck extends StatelessWidget {
  const _EconomyDeck({required this.state, required this.onMint, required this.onRemove, required this.onSend});
  final ControlCenterState state;
  final VoidCallback onMint;
  final VoidCallback onRemove;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Column(children: [
        _VaultCard(balance: state.coinAuthorityBalance),
        const SizedBox(height: 10),
        _CommandGroup(title: 'Authority Pool Controls', children: [
          _CommandRow(icon: Icons.add_circle_rounded, title: 'Mint into pool', subtitle: 'Founder-only source pool increase', accent: _royalGold, onTap: onMint),
          _CommandRow(icon: Icons.remove_circle_rounded, title: 'Remove from pool', subtitle: 'Manual correction / accounting', accent: _rose, onTap: onRemove),
          _CommandRow(icon: Icons.send_rounded, title: 'Send to user', subtitle: 'Reasoned audited transfer', accent: _aqua, onTap: onSend),
        ]),
      ]);
}

class _StealthDeck extends StatelessWidget {
  const _StealthDeck({required this.state, required this.save});
  final ControlCenterState state;
  final Future<void> Function(ControlCenterState Function(ControlCenterState), {String? action, String targetUserId, String roomId, String resourceType, String reason}) save;

  @override
  Widget build(BuildContext context) => _CommandGroup(title: 'Invisible Authority', children: [
        _SwitchCommand(title: 'Invisible allover app', value: state.globalInvisible, onChanged: (v) => save((s) => s.copyWith(globalInvisible: v), action: v ? 'INVISIBILITY_ON' : 'INVISIBILITY_OFF', resourceType: 'presence', reason: 'Global invisibility changed')),
        _SwitchCommand(title: 'Hide from online count', value: state.hideFromOnlineCount, onChanged: (v) => save((s) => s.copyWith(hideFromOnlineCount: v), action: 'ONLINE_COUNT_VISIBILITY_CHANGED', resourceType: 'presence', reason: 'Online count visibility changed')),
        _SwitchCommand(title: 'Hide even when seated', value: state.hideWhenSeated, onChanged: (v) => save((s) => s.copyWith(hideWhenSeated: v), action: 'SEAT_VISIBILITY_CHANGED', resourceType: 'room_seat', reason: 'Seat visibility changed')),
        _SwitchCommand(title: 'Hide room entry events', value: state.hideRoomEntryEvents, onChanged: (v) => save((s) => s.copyWith(hideRoomEntryEvents: v), action: 'ROOM_ENTRY_VISIBILITY_CHANGED', resourceType: 'chat_room', reason: 'Entry visibility changed')),
        _SwitchCommand(title: 'Keep private audit logs', value: state.auditInvisibleAccess, onChanged: (v) => save((s) => s.copyWith(auditInvisibleAccess: v), action: 'INVISIBLE_AUDIT_CHANGED', resourceType: 'admin_log', reason: 'Invisible audit changed')),
      ]);
}

class _PowersDeck extends StatelessWidget {
  const _PowersDeck({required this.state, required this.onGrant, required this.onToggle});
  final ControlCenterState state;
  final VoidCallback onGrant;
  final ValueChanged<PowerGrantEntry> onToggle;

  @override
  Widget build(BuildContext context) => _CommandGroup(title: 'Power Provider', children: [
        _CommandRow(icon: Icons.add_moderator_rounded, title: 'Grant new power', subtitle: 'Role + authority + reason', accent: _royalGold, onTap: onGrant),
        if (state.powerGrants.isEmpty) const _EmptyRow('No powers granted yet.') else ...state.powerGrants.map((grant) => _PowerRow(grant: grant, onTap: () => onToggle(grant))),
      ]);
}

class _ModerationDeck extends StatelessWidget {
  const _ModerationDeck({required this.onAction});
  final Future<void> Function(String action) onAction;

  @override
  Widget build(BuildContext context) => _CommandGroup(title: 'User Authority', children: [
        _CommandRow(icon: Icons.timer_rounded, title: 'Temporary action', subtitle: 'Timed restriction / warning log', accent: _royalGold, onTap: () => onAction('TEMP_BAN_USER')),
        _CommandRow(icon: Icons.block_rounded, title: 'Restrict user', subtitle: 'Ban authority with reason', accent: _rose, onTap: () => onAction('BAN_USER')),
        _CommandRow(icon: Icons.warning_rounded, title: 'Permanent action', subtitle: 'Owner-level permanent restriction', accent: _rose, onTap: () => onAction('PERMANENT_BAN_USER')),
        _CommandRow(icon: Icons.lock_open_rounded, title: 'Restore user', subtitle: 'Unban / restore access', accent: _aqua, onTap: () => onAction('UNBAN_USER')),
      ]);
}

class _IdentityDeck extends StatelessWidget {
  const _IdentityDeck({required this.onCustomId});
  final VoidCallback onCustomId;

  @override
  Widget build(BuildContext context) => _CommandGroup(title: 'Identity Authority', children: [
        _CommandRow(icon: Icons.badge_rounded, title: 'Assign custom ID', subtitle: 'Assign protected premium ID to any user', accent: _royalGold, onTap: onCustomId),
      ]);
}

class _LogsDeck extends StatelessWidget {
  const _LogsDeck({required this.state});
  final ControlCenterState state;

  @override
  Widget build(BuildContext context) => _CommandGroup(title: 'Audit Stream', children: state.logs.map((log) => _AuditRow(log: log)).toList());
}

class _ReviewDeck extends StatelessWidget {
  const _ReviewDeck({required this.state, required this.onReview});
  final ControlCenterState state;
  final Future<void> Function(ReviewQueueItem item, String status) onReview;

  @override
  Widget build(BuildContext context) => _CommandGroup(title: 'Review Queue', children: state.reviewItems.map((item) => _ReviewRow(item: item, onReview: onReview)).toList());
}

class _VaultCard extends StatelessWidget {
  const _VaultCard({required this.balance});
  final int balance;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF251733), Color(0xFF100819)]),
          border: Border.all(color: const Color(0x55FFD36A)),
        ),
        child: Row(children: [
          const Icon(Icons.account_balance_wallet_rounded, color: _royalGold, size: 34),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Founder Authority Pool', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
            Text(_coins(balance), style: const TextStyle(color: _royalGold, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
          ])),
          const _StatusDot(label: 'INFINITE'),
        ]),
      );
}

class _CommandGroup extends StatelessWidget {
  const _CommandGroup({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: _panel.withValues(alpha: 0.82), borderRadius: BorderRadius.circular(22), border: Border.all(color: _line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.fromLTRB(4, 2, 4, 9), child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900))),
          ...children,
        ]),
      );
}

class _CommandRow extends StatelessWidget {
  const _CommandRow({required this.icon, required this.title, required this.subtitle, required this.accent, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: _obsidian, borderRadius: BorderRadius.circular(16), border: Border.all(color: _line)),
          child: Row(children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: accent.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(12), border: Border.all(color: accent.withValues(alpha: 0.32))), child: Icon(icon, color: accent, size: 19)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 10.5, fontWeight: FontWeight.w700)),
            ])),
            const Icon(Icons.chevron_right_rounded, color: _muted, size: 20),
          ]),
        ),
      );
}

class _SwitchCommand extends StatelessWidget {
  const _SwitchCommand({required this.title, required this.value, required this.onChanged});
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
        decoration: BoxDecoration(color: _obsidian, borderRadius: BorderRadius.circular(16), border: Border.all(color: _line)),
        child: Row(children: [
          Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900))),
          Switch.adaptive(value: value, activeThumbColor: _royalGold, activeTrackColor: const Color(0x55FFD36A), onChanged: onChanged),
        ]),
      );
}

class _ConsoleValue extends StatelessWidget {
  const _ConsoleValue({required this.label, required this.value, required this.icon, required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: _obsidian.withValues(alpha: 0.78), borderRadius: BorderRadius.circular(17), border: Border.all(color: _line)),
        child: Row(children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 9.5, fontWeight: FontWeight.w800)),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w900)),
          ])),
        ]),
      );
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: _obsidian.withValues(alpha: 0.72), borderRadius: BorderRadius.circular(999), border: Border.all(color: _line)),
        child: Row(children: [Icon(icon, color: _royalGold, size: 15), const SizedBox(width: 6), Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)))]),
      );
}

class _MetricMini extends StatelessWidget {
  const _MetricMini({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),
        child: Row(children: [Icon(icon, color: _royalGold, size: 18), const SizedBox(width: 8), Text(value, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(width: 5), Expanded(child: Text(label, style: const TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.w800)))]),
      );
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: _royalGold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: _royalGold.withValues(alpha: 0.45))), child: Text(label, style: const TextStyle(color: _royalGold, fontSize: 9.5, fontWeight: FontWeight.w900)));
}

class _PowerRow extends StatelessWidget {
  const _PowerRow({required this.grant, required this.onTap});
  final PowerGrantEntry grant;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => _LineRow(title: '${grant.userId} • ${grant.role}', subtitle: grant.authorities.join(', '), trailing: grant.isActive ? 'Revoke' : 'Restore', onTap: onTap);
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.log});
  final ControlLogEntry log;
  @override
  Widget build(BuildContext context) => _LineRow(title: log.action, subtitle: '${log.targetUserId} • ${log.reason}', trailing: log.chatRoomId == '-' ? 'LOG' : log.chatRoomId);
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.item, required this.onReview});
  final ReviewQueueItem item;
  final Future<void> Function(ReviewQueueItem item, String status) onReview;
  @override
  Widget build(BuildContext context) => _LineRow(title: item.title, subtitle: '${item.type} • ${item.userId}', trailing: item.status, onTap: item.status == 'Pending' ? () => onReview(item, 'Approved') : null);
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.title, required this.subtitle, required this.trailing, this.onTap});
  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(color: _obsidian, borderRadius: BorderRadius.circular(15), border: Border.all(color: _line)),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 10.5, fontWeight: FontWeight.w700)),
            ])),
            const SizedBox(width: 8),
            Text(trailing, style: const TextStyle(color: _royalGold, fontSize: 10.5, fontWeight: FontWeight.w900)),
          ]),
        ),
      );
}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _obsidian, borderRadius: BorderRadius.circular(15), border: Border.all(color: _line)), child: Text(text, style: const TextStyle(color: _muted, fontSize: 11.5, fontWeight: FontWeight.w800)));
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, customBorder: const CircleBorder(), child: Container(width: 38, height: 38, decoration: BoxDecoration(color: _obsidian, shape: BoxShape.circle, border: Border.all(color: _line)), child: Icon(icon, color: Colors.white, size: 21)));
}

class _Denied extends StatelessWidget {
  const _Denied({required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => Center(child: _CommandRow(icon: Icons.arrow_back_rounded, title: 'Protected panel', subtitle: 'Only Founder/Super Owner or Owner can open it', accent: _royalGold, onTap: onBack));
}

String _coins(int value) {
  if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(1)}B';
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toString();
}

class _NumberSheet extends StatefulWidget {
  const _NumberSheet({required this.title});
  final String title;
  static Future<int?> show(BuildContext context, {required String title}) => showModalBottomSheet<int>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => _NumberSheet(title: title));
  @override
  State<_NumberSheet> createState() => _NumberSheetState();
}

class _NumberSheetState extends State<_NumberSheet> {
  final amount = TextEditingController();
  @override
  void dispose() { amount.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => _Sheet(title: widget.title, fields: [_field(amount, 'Coin amount', keyboard: TextInputType.number)], onSubmit: () { final parsed = int.tryParse(amount.text.trim()); if (parsed == null || parsed <= 0) return; Navigator.pop(context, parsed); });
}

class _UserNumberDraft { const _UserNumberDraft({required this.userId, required this.amount}); final String userId; final int amount; }

class _UserNumberSheet extends StatefulWidget {
  const _UserNumberSheet({required this.title});
  final String title;
  static Future<_UserNumberDraft?> show(BuildContext context, {required String title}) => showModalBottomSheet<_UserNumberDraft>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => _UserNumberSheet(title: title));
  @override
  State<_UserNumberSheet> createState() => _UserNumberSheetState();
}

class _UserNumberSheetState extends State<_UserNumberSheet> {
  final user = TextEditingController();
  final amount = TextEditingController();
  @override
  void dispose() { user.dispose(); amount.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => _Sheet(title: widget.title, fields: [_field(user, 'Target user ID'), _field(amount, 'Coin amount', keyboard: TextInputType.number)], onSubmit: () { final parsed = int.tryParse(amount.text.trim()); if (user.text.trim().isEmpty || parsed == null || parsed <= 0) return; Navigator.pop(context, _UserNumberDraft(userId: user.text.trim(), amount: parsed)); });
}

class _UserTextDraft { const _UserTextDraft({required this.userId, required this.text}); final String userId; final String text; }

class _UserTextSheet extends StatefulWidget {
  const _UserTextSheet({required this.title, required this.label});
  final String title;
  final String label;
  static Future<_UserTextDraft?> show(BuildContext context, {required String title, required String label}) => showModalBottomSheet<_UserTextDraft>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => _UserTextSheet(title: title, label: label));
  @override
  State<_UserTextSheet> createState() => _UserTextSheetState();
}

class _UserTextSheetState extends State<_UserTextSheet> {
  final user = TextEditingController();
  final text = TextEditingController();
  @override
  void dispose() { user.dispose(); text.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => _Sheet(title: widget.title, fields: [_field(user, 'Target user ID'), _field(text, widget.label)], onSubmit: () { if (user.text.trim().isEmpty || text.text.trim().isEmpty) return; Navigator.pop(context, _UserTextDraft(userId: user.text.trim(), text: text.text.trim())); });
}

class _PowerDraft { const _PowerDraft({required this.userId, required this.role, required this.authorities, required this.reason}); final String userId; final String role; final List<String> authorities; final String reason; }

class _PowerSheet extends StatefulWidget {
  const _PowerSheet();
  static Future<_PowerDraft?> show(BuildContext context) => showModalBottomSheet<_PowerDraft>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const _PowerSheet());
  @override
  State<_PowerSheet> createState() => _PowerSheetState();
}

class _PowerSheetState extends State<_PowerSheet> {
  final user = TextEditingController();
  final reason = TextEditingController();
  String role = 'monitor';
  final selected = <String>{'TEMP_BAN_USER'};
  @override
  void dispose() { user.dispose(); reason.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => _Sheet(title: 'Grant power', fields: [
        _field(user, 'Target user ID'),
        DropdownButtonFormField<String>(initialValue: role, items: controlCenterRoles.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(), onChanged: (value) => setState(() => role = value ?? role), decoration: _input('Role')),
        const SizedBox(height: 6),
        Wrap(spacing: 5, runSpacing: 5, children: controlCenterAuthorities.take(8).map((item) => FilterChip(label: Text(item, style: const TextStyle(fontSize: 10)), selected: selected.contains(item), onSelected: (value) => setState(() => value ? selected.add(item) : selected.remove(item)))).toList()),
        _field(reason, 'Reason'),
      ], onSubmit: () { if (user.text.trim().isEmpty || reason.text.trim().isEmpty || selected.isEmpty) return; Navigator.pop(context, _PowerDraft(userId: user.text.trim(), role: role, authorities: selected.toList(), reason: reason.text.trim())); });
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.title, required this.fields, required this.onSubmit});
  final String title;
  final List<Widget> fields;
  final VoidCallback onSubmit;
  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(14, 14, 14, 14 + bottom),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: SafeArea(top: false, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _obsidian)),
        const SizedBox(height: 10),
        ...fields,
        SizedBox(width: double.infinity, height: 44, child: FilledButton(onPressed: onSubmit, child: const Text('Submit'))),
      ]))),
    );
  }
}

Widget _field(TextEditingController controller, String label, {TextInputType? keyboard}) => Padding(padding: const EdgeInsets.only(bottom: 8), child: TextField(controller: controller, keyboardType: keyboard, decoration: _input(label)));

InputDecoration _input(String label) => InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFFAF7F1),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: Color(0xFFC99A3B))),
    );
