import 'package:flutter/material.dart';

import '../control_center_models.dart';
import 'super_power_design.dart';

class ControlCockpitOverview extends StatelessWidget {
  const ControlCockpitOverview({
    super.key,
    required this.state,
    required this.onMint,
    required this.onRemovePool,
    required this.onSendCoins,
    required this.onPower,
    required this.onReview,
    required this.onRole,
    required this.onStealthChanged,
  });

  final ControlCenterState state;
  final VoidCallback onMint;
  final VoidCallback onRemovePool;
  final VoidCallback onSendCoins;
  final VoidCallback onPower;
  final VoidCallback onReview;
  final VoidCallback onRole;
  final ValueChanged<bool> onStealthChanged;

  @override
  Widget build(BuildContext context) {
    final pendingReviews = state.reviewItems.where((item) => item.status == 'Pending').length;
    final activeRoles = state.roleAssignments.where((item) => item.isActive).length;
    final activePowers = state.powerGrants.where((item) => item.isActive).length;

    return Column(
      children: [
        _CommandBridge(
          pool: state.coinAuthorityBalance,
          stealthOn: state.globalInvisible,
          onMint: onMint,
          onSend: onSendCoins,
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Column(
                children: [
                  _BentoTile(
                    height: 118,
                    title: 'Officials',
                    value: '$activeRoles',
                    subtitle: 'assign / remove roles',
                    icon: Icons.verified_user_rounded,
                    accent: SuperPowerDesign.gold,
                    onTap: onRole,
                  ),
                  const SizedBox(height: 10),
                  _BentoTile(
                    height: 116,
                    title: 'Powers',
                    value: '$activePowers',
                    subtitle: 'category grants',
                    icon: Icons.admin_panel_settings_rounded,
                    accent: SuperPowerDesign.violet,
                    onTap: onPower,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  _BentoTile(
                    height: 104,
                    title: 'Reviews',
                    value: '$pendingReviews',
                    subtitle: 'mapped tasks',
                    icon: Icons.fact_check_rounded,
                    accent: SuperPowerDesign.aqua,
                    onTap: onReview,
                  ),
                  const SizedBox(height: 10),
                  _StealthToggleTile(
                    height: 104,
                    enabled: state.globalInvisible,
                    onChanged: onStealthChanged,
                  ),
                  const SizedBox(height: 10),
                  _BentoTile(
                    height: 44,
                    title: 'Logs',
                    value: '${state.logs.length}',
                    subtitle: 'audit',
                    icon: Icons.receipt_long_rounded,
                    accent: SuperPowerDesign.rose,
                    onTap: null,
                    compact: true,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _QuickCommandBelt(
          onMint: onMint,
          onRemovePool: onRemovePool,
          onSendCoins: onSendCoins,
          onPower: onPower,
          onReview: onReview,
          onRole: onRole,
        ),
      ],
    );
  }
}

class _StealthToggleTile extends StatelessWidget {
  const _StealthToggleTile({required this.height, required this.enabled, required this.onChanged});

  final double height;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final accent = enabled ? SuperPowerDesign.mint : SuperPowerDesign.muted;
    return InkWell(
      onTap: () => onChanged(!enabled),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: height,
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accent.withValues(alpha: 0.16), const Color(0xFF101624), const Color(0xFF070A12)],
          ),
          border: Border.all(color: accent.withValues(alpha: 0.32)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(enabled ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: accent, size: 18),
              const Spacer(),
              _MiniSwitch(enabled: enabled, color: accent),
            ]),
            const Spacer(),
            Text(enabled ? 'ON' : 'OFF', maxLines: 1, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.7)),
            const SizedBox(height: 1),
            Text('Stealth', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: accent, fontSize: 10.8, fontWeight: FontWeight.w900)),
            const Text('tap to toggle', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: SuperPowerDesign.muted, fontSize: 9.2, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _MiniSwitch extends StatelessWidget {
  const _MiniSwitch({required this.enabled, required this.color});

  final bool enabled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 33,
      height: 18,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: enabled ? color.withValues(alpha: 0.26) : Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.40)),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 180),
        alignment: enabled ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: enabled ? color : SuperPowerDesign.muted, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _CommandBridge extends StatelessWidget {
  const _CommandBridge({required this.pool, required this.stealthOn, required this.onMint, required this.onSend});

  final int pool;
  final bool stealthOn;
  final VoidCallback onMint;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 184,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const RadialGradient(
          center: Alignment.topRight,
          radius: 1.2,
          colors: [Color(0xFF384E84), Color(0xFF131A2B), Color(0xFF070911)],
          stops: [0.0, 0.38, 1.0],
        ),
        border: Border.all(color: SuperPowerDesign.gold.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(color: SuperPowerDesign.aqua.withValues(alpha: 0.08), blurRadius: 32, offset: const Offset(-10, -8)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.48), blurRadius: 28, offset: const Offset(0, 18)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -28,
            top: -30,
            child: Container(
              width: 138,
              height: 138,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: SuperPowerDesign.aqua.withValues(alpha: 0.18), width: 18),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: SuperPowerDesign.gold.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: SuperPowerDesign.gold.withValues(alpha: 0.42)),
                    ),
                    child: const Text(
                      'FOUNDER VAULT',
                      style: TextStyle(color: SuperPowerDesign.gold, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.7),
                    ),
                  ),
                  const Spacer(),
                  _MiniState(label: stealthOn ? 'STEALTH ON' : 'VISIBLE', color: stealthOn ? SuperPowerDesign.mint : SuperPowerDesign.muted),
                ],
              ),
              const Spacer(),
              const Text('Authority Pool', style: TextStyle(color: SuperPowerDesign.muted, fontSize: 12, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(
                SuperPowerDesign.compactCoins(pool),
                style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900, height: 0.95, letterSpacing: -1.4),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _BridgeButton(label: 'Mint', icon: Icons.add_rounded, onTap: onMint, filled: true)),
                  const SizedBox(width: 8),
                  Expanded(child: _BridgeButton(label: 'Send', icon: Icons.send_rounded, onTap: onSend, filled: false)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BentoTile extends StatelessWidget {
  const _BentoTile({
    required this.height,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.compact = false,
  });

  final double height;
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: height,
        width: double.infinity,
        padding: EdgeInsets.all(compact ? 8 : 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accent.withValues(alpha: 0.16), const Color(0xFF101624), const Color(0xFF070A12)],
          ),
          border: Border.all(color: accent.withValues(alpha: 0.32)),
        ),
        child: compact
            ? Row(
                children: [
                  Icon(icon, color: accent, size: 15),
                  const SizedBox(width: 6),
                  Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: SuperPowerDesign.muted, fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Icon(icon, color: accent, size: 18), const Spacer(), if (onTap != null) Icon(Icons.north_east_rounded, color: accent, size: 14)]),
                  const Spacer(),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value, maxLines: 1, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.7)),
                  ),
                  const SizedBox(height: 1),
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: accent, fontSize: 10.8, fontWeight: FontWeight.w900)),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SuperPowerDesign.muted, fontSize: 9.2, fontWeight: FontWeight.w700)),
                ],
              ),
      ),
    );
  }
}

class _QuickCommandBelt extends StatelessWidget {
  const _QuickCommandBelt({required this.onMint, required this.onRemovePool, required this.onSendCoins, required this.onPower, required this.onReview, required this.onRole});

  final VoidCallback onMint;
  final VoidCallback onRemovePool;
  final VoidCallback onSendCoins;
  final VoidCallback onPower;
  final VoidCallback onReview;
  final VoidCallback onRole;

  @override
  Widget build(BuildContext context) {
    final items = <_BeltItem>[
      _BeltItem('Roles', Icons.verified_user_rounded, SuperPowerDesign.gold, onRole),
      _BeltItem('Power', Icons.admin_panel_settings_rounded, SuperPowerDesign.violet, onPower),
      _BeltItem('Review', Icons.fact_check_rounded, SuperPowerDesign.aqua, onReview),
      _BeltItem('Mint', Icons.add_circle_rounded, SuperPowerDesign.gold, onMint),
      _BeltItem('Remove', Icons.remove_circle_rounded, SuperPowerDesign.rose, onRemovePool),
      _BeltItem('Send', Icons.send_rounded, SuperPowerDesign.mint, onSendCoins),
    ];

    return SizedBox(
      height: 82,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          return InkWell(
            onTap: item.onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 84,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0B101B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: item.color.withValues(alpha: 0.34)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.icon, color: item.color, size: 22),
                  const SizedBox(height: 7),
                  Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BeltItem {
  const _BeltItem(this.label, this.icon, this.color, this.onTap);
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _BridgeButton extends StatelessWidget {
  const _BridgeButton({required this.label, required this.icon, required this.onTap, required this.filled});

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          gradient: filled ? SuperPowerDesign.goldGradient : null,
          color: filled ? null : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: filled ? Colors.transparent : SuperPowerDesign.aqua.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: filled ? SuperPowerDesign.obsidian : SuperPowerDesign.aqua, size: 18),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: filled ? SuperPowerDesign.obsidian : Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _MiniState extends StatelessWidget {
  const _MiniState({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: 0.36))),
      child: Text(label, style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w900)),
    );
  }
}

