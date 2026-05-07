import 'package:flutter/material.dart';

import 'control_center_models.dart';
import 'control_center_store.dart';

class SuperOwnerControlCenterPage extends StatefulWidget {
  const SuperOwnerControlCenterPage({super.key, required this.currentRole});

  final String currentRole;

  @override
  State<SuperOwnerControlCenterPage> createState() => _SuperOwnerControlCenterPageState();
}

class _SuperOwnerControlCenterPageState extends State<SuperOwnerControlCenterPage> {
  ControlCenterSection _section = ControlCenterSection.overview;
  ControlCenterState? _state;
  bool _busy = false;
  String _logGroup = 'User ID';

  bool get _isAllowed {
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
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF08050D), content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800))));
  }

  Future<void> _update(ControlCenterState Function(ControlCenterState current) update, {String? action, String targetUserId = '-', String roomId = '-', String resourceType = 'control_center', String reason = 'Super Owner control update'}) async {
    final current = _state;
    if (current == null || _busy) return;
    setState(() => _busy = true);
    var next = update(current);
    if (action != null) {
      next = await ControlCenterStore.writeLog(next, action: action, targetUserId: targetUserId, chatRoomId: roomId, resourceType: resourceType, reason: reason);
    } else {
      await ControlCenterStore.save(next);
    }
    if (!mounted) return;
    setState(() {
      _state = next;
      _busy = false;
    });
  }

  Future<void> _openPowerGrantSheet() async {
    final result = await showModalBottomSheet<_PowerGrantDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PowerGrantSheet(),
    );
    if (result == null) return;
    await _update(
      (state) => state.copyWith(
        powerGrants: <PowerGrantEntry>[
          PowerGrantEntry(
            id: 'PWR-${DateTime.now().millisecondsSinceEpoch}',
            userId: result.userId,
            role: result.role,
            authorities: result.authorities,
            reason: result.reason,
            isActive: true,
            createdAt: DateTime.now(),
          ),
          ...state.powerGrants,
        ],
      ),
      action: 'POWER_GRANTED',
      targetUserId: result.userId,
      resourceType: 'special_permission',
      reason: result.reason,
    );
    _toast('Power granted to ${result.userId}.');
  }

  Future<void> _openUserActionSheet({required String title, required String action, required String resourceType}) async {
    final result = await showModalBottomSheet<_UserActionDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserActionSheet(title: title),
    );
    if (result == null) return;
    await _update((state) => state, action: action, targetUserId: result.userId, roomId: result.roomId, resourceType: resourceType, reason: result.reason);
    _toast('$title submitted for ${result.userId}.');
  }

  Future<void> _openCoinSheet() async {
    final result = await showModalBottomSheet<_CoinDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CoinSendSheet(),
    );
    if (result == null) return;
    final state = _state;
    if (state == null) return;
    if (result.amount > state.coinAuthorityBalance) {
      _toast('Not enough authority pool coins.');
      return;
    }
    await _update(
      (current) => current.copyWith(coinAuthorityBalance: current.coinAuthorityBalance - result.amount),
      action: 'COINS_SENT',
      targetUserId: result.userId,
      resourceType: 'wallet',
      reason: '${result.amount} coins - ${result.reason}',
    );
    _toast('Coins sent to ${result.userId}.');
  }

  Future<void> _openCustomIdSheet() async {
    final result = await showModalBottomSheet<_CustomIdDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CustomIdSheet(),
    );
    if (result == null) return;
    await _update((state) => state, action: 'CUSTOM_ID_ASSIGNED', targetUserId: result.userId, resourceType: 'identity', reason: 'Assigned ${result.customId}: ${result.reason}');
    _toast('Custom ID assigned to ${result.userId}.');
  }

  Future<void> _reviewItem(ReviewQueueItem item, String status) async {
    await _update(
      (state) => state.copyWith(reviewItems: state.reviewItems.map((entry) => entry.id == item.id ? entry.copyWith(status: status) : entry).toList()),
      action: 'REVIEW_$status'.toUpperCase(),
      targetUserId: item.userId,
      roomId: item.roomId,
      resourceType: item.type,
      reason: '${item.title} marked $status',
    );
    _toast('Review marked $status.');
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;

    return Scaffold(
      backgroundColor: const Color(0xFF08050D),
      body: SafeArea(
        child: !_isAllowed
            ? _AccessDenied(onBack: () => Navigator.pop(context))
            : Column(
                children: [
                  _ControlHeader(onBack: () => Navigator.pop(context), busy: _busy),
                  if (state == null)
                    const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.white)))
                  else
                    Expanded(
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
                        children: [
                          _SectionChips(selected: _section, onSelected: (value) => setState(() => _section = value)),
                          const SizedBox(height: 14),
                          if (_section == ControlCenterSection.overview) _OverviewSection(state: state, onCoinTap: _openCoinSheet, onCustomIdTap: _openCustomIdSheet, onPowerTap: _openPowerGrantSheet),
                          if (_section == ControlCenterSection.invisibility) _InvisibilitySection(state: state, onToggle: _update),
                          if (_section == ControlCenterSection.logs) _LogsSection(state: state, groupBy: _logGroup, onGroupChanged: (value) => setState(() => _logGroup = value)),
                          if (_section == ControlCenterSection.powers) _PowersSection(state: state, onGrant: _openPowerGrantSheet, onToggleGrant: (grant) => _update((s) => s.copyWith(powerGrants: s.powerGrants.map((entry) => entry.id == grant.id ? entry.copyWith(isActive: !entry.isActive) : entry).toList()), action: grant.isActive ? 'POWER_REVOKED' : 'POWER_RESTORED', targetUserId: grant.userId, resourceType: 'special_permission', reason: grant.reason)),
                          if (_section == ControlCenterSection.bans) _BansSection(onBan: () => _openUserActionSheet(title: 'Ban user', action: 'BAN_USER', resourceType: 'user_ban'), onUnban: () => _openUserActionSheet(title: 'Unban user', action: 'UNBAN_USER', resourceType: 'user_ban'), onTempBan: () => _openUserActionSheet(title: 'Temporary ban', action: 'TEMP_BAN_USER', resourceType: 'user_ban'), onPermanentBan: () => _openUserActionSheet(title: 'Permanent ban', action: 'PERMANENT_BAN_USER', resourceType: 'user_ban')),
                          if (_section == ControlCenterSection.review) _ReviewSection(state: state, onReview: _reviewItem),
                          if (_section == ControlCenterSection.economy) _EconomySection(state: state, onSendCoins: _openCoinSheet),
                          if (_section == ControlCenterSection.identity) _IdentitySection(onAssignCustomId: _openCustomIdSheet),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _ControlHeader extends StatelessWidget {
  const _ControlHeader({required this.onBack, required this.busy});
  final VoidCallback onBack;
  final bool busy;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 14, 10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)))),
      child: Row(children: [
        IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28)),
        const Expanded(child: Text('Master Control Centre', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -0.4))),
        if (busy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2)),
      ]),
    );
  }
}

class _SectionChips extends StatelessWidget {
  const _SectionChips({required this.selected, required this.onSelected});
  final ControlCenterSection selected;
  final ValueChanged<ControlCenterSection> onSelected;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ControlCenterSection.values.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final section = ControlCenterSection.values[index];
          final active = section == selected;
          return InkWell(
            onTap: () => onSelected(section),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(color: active ? const Color(0xFFFFD36A) : Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(999), border: Border.all(color: active ? const Color(0xFFFFD36A) : Colors.white.withValues(alpha: 0.10))),
              child: Row(children: [Icon(section.icon, size: 16, color: active ? const Color(0xFF251538) : Colors.white), const SizedBox(width: 6), Text(section.label, style: TextStyle(color: active ? const Color(0xFF251538) : Colors.white, fontSize: 12, fontWeight: FontWeight.w900))]),
            ),
          );
        },
      ),
    );
  }
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({required this.state, required this.onCoinTap, required this.onCustomIdTap, required this.onPowerTap});
  final ControlCenterState state;
  final VoidCallback onCoinTap;
  final VoidCallback onCustomIdTap;
  final VoidCallback onPowerTap;
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _HeroPanel(title: 'Super Owner Authority', subtitle: 'Protected master panel. Lower roles cannot modify these controls.', icon: Icons.workspace_premium_rounded),
      const SizedBox(height: 12),
      GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.3, children: [
        _MetricCard(label: 'Invisible', value: state.globalInvisible ? 'ON' : 'OFF', icon: Icons.visibility_off_rounded),
        _MetricCard(label: 'Authority Pool', value: _formatCoins(state.coinAuthorityBalance), icon: Icons.monetization_on_rounded),
        _MetricCard(label: 'Logs', value: state.logs.length.toString(), icon: Icons.receipt_long_rounded),
        _MetricCard(label: 'Pending Review', value: state.reviewItems.where((item) => item.status == 'Pending').length.toString(), icon: Icons.fact_check_rounded),
      ]),
      const SizedBox(height: 12),
      _ActionPanel(actions: [
        _PanelAction(title: 'Power Provider', icon: Icons.admin_panel_settings_rounded, onTap: onPowerTap),
        _PanelAction(title: 'Send Coins', icon: Icons.monetization_on_rounded, onTap: onCoinTap),
        _PanelAction(title: 'Assign Custom ID', icon: Icons.badge_rounded, onTap: onCustomIdTap),
      ]),
    ]);
  }
}

class _InvisibilitySection extends StatelessWidget {
  const _InvisibilitySection({required this.state, required this.onToggle});
  final ControlCenterState state;
  final Future<void> Function(ControlCenterState Function(ControlCenterState), {String? action, String targetUserId, String roomId, String resourceType, String reason}) onToggle;
  @override
  Widget build(BuildContext context) {
    return _Panel(title: 'Global Invisibility', subtitle: 'Founder/Super Owner can hide allover app, including online count and seated state. Backend must enforce realtime presence.', children: [
      _SwitchTile(title: 'Invisible allover app', subtitle: 'Hide public presence across profile, room lists, activity and discovery.', value: state.globalInvisible, onChanged: (value) => onToggle((s) => s.copyWith(globalInvisible: value), action: value ? 'INVISIBILITY_ON' : 'INVISIBILITY_OFF', resourceType: 'presence', reason: 'Master invisibility toggle')),
      _SwitchTile(title: 'Hide from online count', subtitle: 'Do not increase room/user online counters while invisible.', value: state.hideFromOnlineCount, onChanged: (value) => onToggle((s) => s.copyWith(hideFromOnlineCount: value), action: 'ONLINE_COUNT_VISIBILITY_CHANGED', resourceType: 'presence', reason: 'Online count visibility changed')),
      _SwitchTile(title: 'Hide even when seated', subtitle: 'Seat should appear empty/hidden according to Super Owner stealth rules.', value: state.hideWhenSeated, onChanged: (value) => onToggle((s) => s.copyWith(hideWhenSeated: value), action: 'SEAT_VISIBILITY_CHANGED', resourceType: 'room_seat', reason: 'Seat visibility changed')),
      _SwitchTile(title: 'Hide room entry events', subtitle: 'No public entered-room event, activity status or mini profile room location.', value: state.hideRoomEntryEvents, onChanged: (value) => onToggle((s) => s.copyWith(hideRoomEntryEvents: value), action: 'ROOM_ENTRY_VISIBILITY_CHANGED', resourceType: 'chat_room', reason: 'Room entry visibility changed')),
      _SwitchTile(title: 'Audit invisible access', subtitle: 'Keep private backend security logs even when public visibility is hidden.', value: state.auditInvisibleAccess, onChanged: (value) => onToggle((s) => s.copyWith(auditInvisibleAccess: value), action: 'INVISIBLE_AUDIT_CHANGED', resourceType: 'admin_log', reason: 'Invisible audit setting changed')),
    ]);
  }
}

class _LogsSection extends StatelessWidget {
  const _LogsSection({required this.state, required this.groupBy, required this.onGroupChanged});
  final ControlCenterState state;
  final String groupBy;
  final ValueChanged<String> onGroupChanged;
  @override
  Widget build(BuildContext context) {
    final groups = <String, List<ControlLogEntry>>{};
    for (final log in state.logs) {
      final key = groupBy == 'Room ID' ? log.chatRoomId : groupBy == 'Action' ? log.action : log.targetUserId;
      groups.putIfAbsent(key.isEmpty ? '-' : key, () => <ControlLogEntry>[]).add(log);
    }
    return _Panel(title: 'Grouped Logs', subtitle: 'Matches backend admin_logs shape: actor, target user, resource, room id, reason and timestamp.', children: [
      Wrap(spacing: 8, children: ['User ID', 'Room ID', 'Action'].map((item) => ChoiceChip(label: Text(item), selected: groupBy == item, onSelected: (_) => onGroupChanged(item))).toList()),
      const SizedBox(height: 10),
      ...groups.entries.map((entry) => _LogGroupCard(title: entry.key, logs: entry.value)),
    ]);
  }
}

class _PowersSection extends StatelessWidget {
  const _PowersSection({required this.state, required this.onGrant, required this.onToggleGrant});
  final ControlCenterState state;
  final VoidCallback onGrant;
  final ValueChanged<PowerGrantEntry> onToggleGrant;
  @override
  Widget build(BuildContext context) {
    return _Panel(title: 'Power Provider', subtitle: 'Grant role-aligned powers. Backend currently has BAN_USER, UNBAN_USER, TEMP_BAN_USER, PERMANENT_BAN_USER; UI is prepared for master authorities.', children: [
      _PrimaryButton(label: 'Grant power to user', icon: Icons.add_moderator_rounded, onTap: onGrant),
      const SizedBox(height: 10),
      if (state.powerGrants.isEmpty) const _EmptyLine('No active power grants yet.') else ...state.powerGrants.map((grant) => _PowerGrantCard(grant: grant, onToggle: () => onToggleGrant(grant))),
    ]);
  }
}

class _BansSection extends StatelessWidget {
  const _BansSection({required this.onBan, required this.onUnban, required this.onTempBan, required this.onPermanentBan});
  final VoidCallback onBan;
  final VoidCallback onUnban;
  final VoidCallback onTempBan;
  final VoidCallback onPermanentBan;
  @override
  Widget build(BuildContext context) {
    return _Panel(title: 'Ban & Unban Authority', subtitle: 'Super Owner/Owner level ban authority. Lower special-permission users cannot modify officials or owner-issued bans.', children: [
      _ActionPanel(actions: [
        _PanelAction(title: 'Temp Ban', icon: Icons.timer_rounded, onTap: onTempBan),
        _PanelAction(title: 'Ban User', icon: Icons.block_rounded, onTap: onBan),
        _PanelAction(title: 'Permanent Ban', icon: Icons.warning_rounded, onTap: onPermanentBan),
        _PanelAction(title: 'Unban User', icon: Icons.lock_open_rounded, onTap: onUnban),
      ]),
    ]);
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({required this.state, required this.onReview});
  final ControlCenterState state;
  final Future<void> Function(ReviewQueueItem, String) onReview;
  @override
  Widget build(BuildContext context) {
    return _Panel(title: 'Review Panel', subtitle: 'Reports, custom uploaded backgrounds, DP reviews, payout/economy flags and CS escalations.', children: state.reviewItems.map((item) => _ReviewCard(item: item, onApprove: () => onReview(item, 'Approved'), onReject: () => onReview(item, 'Rejected'))).toList());
  }
}

class _EconomySection extends StatelessWidget {
  const _EconomySection({required this.state, required this.onSendCoins});
  final ControlCenterState state;
  final VoidCallback onSendCoins;
  @override
  Widget build(BuildContext context) {
    return _Panel(title: 'Coin Authority', subtitle: 'Send coins to any user from authority pool. Backend must audit source pool, reason and target user.', children: [
      _MetricCard(label: 'Authority Pool', value: _formatCoins(state.coinAuthorityBalance), icon: Icons.account_balance_wallet_rounded),
      const SizedBox(height: 12),
      _PrimaryButton(label: 'Send coins to user', icon: Icons.send_rounded, onTap: onSendCoins),
    ]);
  }
}

class _IdentitySection extends StatelessWidget {
  const _IdentitySection({required this.onAssignCustomId});
  final VoidCallback onAssignCustomId;
  @override
  Widget build(BuildContext context) {
    return _Panel(title: 'Custom ID Authority', subtitle: 'Assign premium display custom ID to any user. Backend must validate uniqueness and protect official IDs.', children: [
      _PrimaryButton(label: 'Assign custom ID', icon: Icons.badge_rounded, onTap: onAssignCustomId),
    ]);
  }
}

// Shared UI
class _Panel extends StatelessWidget { const _Panel({required this.title, required this.subtitle, required this.children}); final String title; final String subtitle; final List<Widget> children; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: _panelDecoration(), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.68), fontSize: 12, height: 1.3, fontWeight: FontWeight.w700)), const SizedBox(height: 14), ...children])); }
class _HeroPanel extends StatelessWidget { const _HeroPanel({required this.title, required this.subtitle, required this.icon}); final String title; final String subtitle; final IconData icon; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: _panelDecoration(), child: Row(children: [Container(width: 54, height: 54, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFFFFD36A), Color(0xFFE84C72)])), child: Icon(icon, color: Colors.white)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.68), fontSize: 12, height: 1.3, fontWeight: FontWeight.w700))]))])); }
class _MetricCard extends StatelessWidget { const _MetricCard({required this.label, required this.value, required this.icon}); final String label; final String value; final IconData icon; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: _panelDecoration(), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: const Color(0xFFFFD36A)), const Spacer(), Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)), Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12, fontWeight: FontWeight.w800))])); }
class _SwitchTile extends StatelessWidget { const _SwitchTile({required this.title, required this.subtitle, required this.value, required this.onChanged}); final String title; final String subtitle; final bool value; final ValueChanged<bool> onChanged; @override Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(18)), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.62), fontSize: 11.5, height: 1.25, fontWeight: FontWeight.w700))])), Switch.adaptive(value: value, activeThumbColor: const Color(0xFFFFD36A), activeTrackColor: const Color(0xFFFFD36A).withValues(alpha: 0.35), onChanged: onChanged)])); }
class _PanelAction { const _PanelAction({required this.title, required this.icon, required this.onTap}); final String title; final IconData icon; final VoidCallback onTap; }
class _ActionPanel extends StatelessWidget { const _ActionPanel({required this.actions}); final List<_PanelAction> actions; @override Widget build(BuildContext context) => GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: actions.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.2), itemBuilder: (context, index) { final action = actions[index]; return _PrimaryButton(label: action.title, icon: action.icon, onTap: action.onTap); }); }
class _PrimaryButton extends StatelessWidget { const _PrimaryButton({required this.label, required this.icon, required this.onTap}); final String label; final IconData icon; final VoidCallback onTap; @override Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Container(alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12), decoration: BoxDecoration(color: const Color(0xFFFFD36A), borderRadius: BorderRadius.circular(16)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: const Color(0xFF251538), size: 18), const SizedBox(width: 7), Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w900, fontSize: 12))) ]))); }
class _EmptyLine extends StatelessWidget { const _EmptyLine(this.text); final String text; @override Widget build(BuildContext context) => Text(text, style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontWeight: FontWeight.w700)); }

class _LogGroupCard extends StatelessWidget { const _LogGroupCard({required this.title, required this.logs}); final String title; final List<ControlLogEntry> logs; @override Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(18)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$title (${logs.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)), const SizedBox(height: 8), ...logs.take(4).map((log) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('${log.action} - ${log.reason}', style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontSize: 11.5, fontWeight: FontWeight.w700))))])); }
class _PowerGrantCard extends StatelessWidget { const _PowerGrantCard({required this.grant, required this.onToggle}); final PowerGrantEntry grant; final VoidCallback onToggle; @override Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(18)), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${grant.userId} - ${grant.role}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(grant.authorities.join(', '), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.64), fontSize: 11, fontWeight: FontWeight.w700))])), TextButton(onPressed: onToggle, child: Text(grant.isActive ? 'Revoke' : 'Restore'))])); }
class _ReviewCard extends StatelessWidget { const _ReviewCard({required this.item, required this.onApprove, required this.onReject}); final ReviewQueueItem item; final VoidCallback onApprove; final VoidCallback onReject; @override Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(18)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text('${item.type} - user ${item.userId} - room ${item.roomId} - ${item.status}', style: TextStyle(color: Colors.white.withValues(alpha: 0.64), fontSize: 11.5, fontWeight: FontWeight.w700)), const SizedBox(height: 10), Row(children: [Expanded(child: OutlinedButton(onPressed: item.status == 'Pending' ? onReject : null, child: const Text('Reject'))), const SizedBox(width: 8), Expanded(child: FilledButton(onPressed: item.status == 'Pending' ? onApprove : null, child: const Text('Approve')))])])); }

class _AccessDenied extends StatelessWidget { const _AccessDenied({required this.onBack}); final VoidCallback onBack; @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.lock_rounded, color: Colors.white, size: 54), const SizedBox(height: 12), const Text('Control Centre is protected', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)), const SizedBox(height: 8), Text('Only Founder/Super Owner or Owner roles can open this panel.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.66), fontWeight: FontWeight.w700)), const SizedBox(height: 16), _PrimaryButton(label: 'Go back', icon: Icons.arrow_back_rounded, onTap: onBack)]))); }

BoxDecoration _panelDecoration() => BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withValues(alpha: 0.10)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 8))]);
String _formatCoins(int value) { if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M'; if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K'; return value.toString(); }

// Sheets
class _PowerGrantDraft { const _PowerGrantDraft({required this.userId, required this.role, required this.authorities, required this.reason}); final String userId; final String role; final List<String> authorities; final String reason; }
class _UserActionDraft { const _UserActionDraft({required this.userId, required this.roomId, required this.reason}); final String userId; final String roomId; final String reason; }
class _CoinDraft { const _CoinDraft({required this.userId, required this.amount, required this.reason}); final String userId; final int amount; final String reason; }
class _CustomIdDraft { const _CustomIdDraft({required this.userId, required this.customId, required this.reason}); final String userId; final String customId; final String reason; }

class _SimpleFormSheet<T> extends StatefulWidget { const _SimpleFormSheet({required this.title, required this.buildResult, this.showAmount = false, this.showCustomId = false}); final String title; final T? Function(String userId, String roomId, String amountOrCustomId, String reason) buildResult; final bool showAmount; final bool showCustomId; @override State<_SimpleFormSheet<T>> createState() => _SimpleFormSheetState<T>(); }
class _SimpleFormSheetState<T> extends State<_SimpleFormSheet<T>> { final user = TextEditingController(); final room = TextEditingController(text: '-'); final extra = TextEditingController(); final reason = TextEditingController(); @override void dispose(){user.dispose();room.dispose();extra.dispose();reason.dispose();super.dispose();} @override Widget build(BuildContext context){ final bottom = MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom; return Container(margin: const EdgeInsets.all(14), padding: EdgeInsets.fromLTRB(16,16,16,16+bottom), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)), child: SafeArea(top:false, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(widget.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 12), _field(user,'Target user ID'), _field(room,'Room ID / -'), if(widget.showAmount || widget.showCustomId) _field(extra, widget.showAmount ? 'Coin amount' : 'Custom ID'), _field(reason,'Reason'), const SizedBox(height: 12), FilledButton(onPressed: (){ final result = widget.buildResult(user.text.trim(), room.text.trim(), extra.text.trim(), reason.text.trim()); if(result!=null) Navigator.pop(context,result); }, child: const Text('Submit'))]))));} Widget _field(TextEditingController c,String label)=>Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller:c, decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))))); }
class _UserActionSheet extends StatelessWidget { const _UserActionSheet({required this.title}); final String title; @override Widget build(BuildContext context)=>_SimpleFormSheet<_UserActionDraft>(title:title, buildResult:(u,r,e,reason)=> u.isEmpty||reason.isEmpty?null:_UserActionDraft(userId:u, roomId:r.isEmpty?'-':r, reason:reason)); }
class _CoinSendSheet extends StatelessWidget { const _CoinSendSheet(); @override Widget build(BuildContext context)=>_SimpleFormSheet<_CoinDraft>(title:'Send coins', showAmount:true, buildResult:(u,r,amount,reason){ final parsed=int.tryParse(amount); if(u.isEmpty||parsed==null||parsed<=0||reason.isEmpty)return null; return _CoinDraft(userId:u, amount:parsed, reason:reason);}); }
class _CustomIdSheet extends StatelessWidget { const _CustomIdSheet(); @override Widget build(BuildContext context)=>_SimpleFormSheet<_CustomIdDraft>(title:'Assign custom ID', showCustomId:true, buildResult:(u,r,id,reason)=>u.isEmpty||id.isEmpty||reason.isEmpty?null:_CustomIdDraft(userId:u, customId:id, reason:reason)); }

class _PowerGrantSheet extends StatefulWidget { const _PowerGrantSheet(); @override State<_PowerGrantSheet> createState()=>_PowerGrantSheetState(); }
class _PowerGrantSheetState extends State<_PowerGrantSheet>{ final user=TextEditingController(); final reason=TextEditingController(); String role='monitor'; final selected=<String>{'TEMP_BAN_USER'}; @override void dispose(){user.dispose();reason.dispose();super.dispose();} @override Widget build(BuildContext context){ final bottom=MediaQuery.viewInsetsOf(context).bottom+MediaQuery.paddingOf(context).bottom; return Container(margin: const EdgeInsets.all(14), padding: EdgeInsets.fromLTRB(16,16,16,16+bottom), decoration: BoxDecoration(color: Colors.white,borderRadius: BorderRadius.circular(28)), child: SafeArea(top:false, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,crossAxisAlignment: CrossAxisAlignment.start, children:[const Text('Grant power', style: TextStyle(fontSize:20,fontWeight:FontWeight.w900)), const SizedBox(height:12), TextField(controller:user, decoration: InputDecoration(labelText:'Target user ID', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))), const SizedBox(height:10), DropdownButtonFormField<String>(initialValue:role, items: controlCenterRoles.map((r)=>DropdownMenuItem(value:r,child:Text(r))).toList(), onChanged:(v)=>setState(()=>role=v??role), decoration: InputDecoration(labelText:'Role', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))), const SizedBox(height:10), Wrap(spacing:6, runSpacing:6, children: controlCenterAuthorities.map((a)=>FilterChip(label:Text(a), selected:selected.contains(a), onSelected:(v)=>setState(()=>v?selected.add(a):selected.remove(a)))).toList()), const SizedBox(height:10), TextField(controller:reason, decoration: InputDecoration(labelText:'Reason', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))), const SizedBox(height:12), FilledButton(onPressed:(){ if(user.text.trim().isEmpty||reason.text.trim().isEmpty||selected.isEmpty)return; Navigator.pop(context,_PowerGrantDraft(userId:user.text.trim(), role:role, authorities:selected.toList(), reason:reason.text.trim())); }, child: const Text('Grant power'))]))));}}
