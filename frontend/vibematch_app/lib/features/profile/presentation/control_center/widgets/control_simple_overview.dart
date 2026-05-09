import 'package:flutter/material.dart';

import '../control_center_models.dart';
import 'super_power_design.dart';

class ControlSimpleOverview extends StatelessWidget {
  const ControlSimpleOverview({
    super.key,
    required this.state,
    required this.onStealthChanged,
    required this.onMint,
    required this.onSendCoins,
    required this.onUserControl,
    required this.onPowerControl,
    required this.onRoleControl,
    required this.onReview,
    required this.onPerformance,
  });

  final ControlCenterState state;
  final ValueChanged<bool> onStealthChanged;
  final VoidCallback onMint;
  final VoidCallback onSendCoins;
  final VoidCallback onUserControl;
  final VoidCallback onPowerControl;
  final VoidCallback onRoleControl;
  final VoidCallback onReview;
  final VoidCallback onPerformance;

  @override
  Widget build(BuildContext context) {
    final activeRoles = state.roleAssignments.where((item) => item.isActive).length;
    final pendingReviews = state.reviewItems.where((item) => item.status == 'Pending').length;
    final activePowers = state.powerGrants.where((item) => item.isActive).length;

    return Column(
      children: [
        _MasterCard(
          pool: state.coinAuthorityBalance,
          stealthOn: state.globalInvisible,
          onStealthChanged: onStealthChanged,
          onMint: onMint,
          onSendCoins: onSendCoins,
        ),
        const SizedBox(height: 12),
        _ControlCard(
          icon: Icons.gavel_rounded,
          title: 'User Control',
          subtitle: 'Ban days, device ban, unban, restore access',
          value: 'Master',
          accent: SuperPowerDesign.rose,
          onTap: onUserControl,
        ),
        _ControlCard(
          icon: Icons.admin_panel_settings_rounded,
          title: 'Power Control',
          subtitle: 'Assign particular powers to a selected user',
          value: '$activePowers active',
          accent: SuperPowerDesign.violet,
          onTap: onPowerControl,
        ),
        _ControlCard(
          icon: Icons.verified_user_rounded,
          title: 'Role Control',
          subtitle: 'Assign or remove official app roles',
          value: '$activeRoles roles',
          accent: SuperPowerDesign.gold,
          onTap: onRoleControl,
        ),
        _ControlCard(
          icon: Icons.fact_check_rounded,
          title: 'Review & Logs',
          subtitle: 'Mapped tasks and audit records',
          value: '$pendingReviews pending',
          accent: SuperPowerDesign.aqua,
          onTap: onReview,
        ),
        _ControlCard(
          icon: Icons.insights_rounded,
          title: 'Performance',
          subtitle: 'Compare officials, sellers, merchants, agencies and users',
          value: 'Compare',
          accent: SuperPowerDesign.mint,
          onTap: onPerformance,
        ),
      ],
    );
  }
}

class _MasterCard extends StatelessWidget {
  const _MasterCard({required this.pool, required this.stealthOn, required this.onStealthChanged, required this.onMint, required this.onSendCoins});

  final int pool;
  final bool stealthOn;
  final ValueChanged<bool> onStealthChanged;
  final VoidCallback onMint;
  final VoidCallback onSendCoins;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B101B),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: SuperPowerDesign.gold.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Super Owner Control', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
              SizedBox(height: 2),
              Text('Simple master controls for the entire app', style: TextStyle(color: SuperPowerDesign.muted, fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
          ),
          _StealthSwitch(value: stealthOn, onChanged: onStealthChanged),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: SuperPowerDesign.obsidian,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: SuperPowerDesign.stroke),
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Authority Pool', style: TextStyle(color: SuperPowerDesign.muted, fontSize: 10.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(SuperPowerDesign.compactCoins(pool), style: const TextStyle(color: SuperPowerDesign.gold, fontSize: 27, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
            ])),
            _SmallButton(label: 'Mint', icon: Icons.add_rounded, color: SuperPowerDesign.gold, onTap: onMint),
            const SizedBox(width: 8),
            _SmallButton(label: 'Send', icon: Icons.send_rounded, color: SuperPowerDesign.aqua, onTap: onSendCoins),
          ]),
        ),
      ]),
    );
  }
}

class _StealthSwitch extends StatelessWidget {
  const _StealthSwitch({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
        decoration: BoxDecoration(
          color: value ? SuperPowerDesign.mint.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: value ? SuperPowerDesign.mint.withValues(alpha: 0.45) : SuperPowerDesign.stroke),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(value ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: value ? SuperPowerDesign.mint : SuperPowerDesign.muted, size: 15),
          const SizedBox(width: 5),
          Text(value ? 'Stealth ON' : 'Stealth OFF', style: TextStyle(color: value ? SuperPowerDesign.mint : SuperPowerDesign.muted, fontSize: 10.5, fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }
}

class _ControlCard extends StatelessWidget {
  const _ControlCard({required this.icon, required this.title, required this.subtitle, required this.value, required this.accent, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0B101B),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: SuperPowerDesign.stroke),
          ),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(13)),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 11),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13.2, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SuperPowerDesign.muted, fontSize: 10.6, fontWeight: FontWeight.w700)),
            ])),
            const SizedBox(width: 8),
            Text(value, style: TextStyle(color: accent, fontSize: 10.5, fontWeight: FontWeight.w900)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: accent, size: 20),
          ]),
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.label, required this.icon, required this.color, required this.onTap});
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(13), border: Border.all(color: color.withValues(alpha: 0.35))),
        child: Row(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }
}
