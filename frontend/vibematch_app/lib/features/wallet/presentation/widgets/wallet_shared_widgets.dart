import 'package:flutter/material.dart';

import '../models/wallet_models.dart';

class WalletColors {
  const WalletColors._();

  static const bg = Color(0xFFFAF7F1);
  static const deep = Color(0xFF251538);
  static const plum = Color(0xFF4A2A63);
  static const border = Color(0xFFECE2D8);
  static const gold = Color(0xFFC99A3B);
  static const coral = Color(0xFFE84C72);
  static const aqua = Color(0xFF12C7B7);
}

class WalletHeaderIconButton extends StatelessWidget {
  const WalletHeaderIconButton({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: WalletColors.bg,
            border: Border.all(color: WalletColors.border),
          ),
          child: Icon(icon, color: WalletColors.deep, size: 19),
        ),
      ),
    );
  }
}

class WalletWhiteCard extends StatelessWidget {
  const WalletWhiteCard({super.key, required this.child, this.padding = const EdgeInsets.all(14)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: WalletColors.border),
        boxShadow: [
          BoxShadow(
            color: WalletColors.deep.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class WalletInfoCard extends StatelessWidget {
  const WalletInfoCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.rows,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<WalletInfoRow> rows;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return WalletWhiteCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: 0.12)),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: WalletColors.deep, fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: Color(0xFF6F627A), fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 14),
          ...rows.map((row) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(row.label, style: const TextStyle(color: Color(0xFF6F627A), fontSize: 12, fontWeight: FontWeight.w800))),
                    Text(row.value, style: const TextStyle(color: WalletColors.deep, fontSize: 13, fontWeight: FontWeight.w900)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class WalletInfoRow {
  const WalletInfoRow({required this.label, required this.value});

  final String label;
  final String value;
}

class WalletMiniActionChip extends StatelessWidget {
  const WalletMiniActionChip({super.key, required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: WalletColors.bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: WalletColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: WalletColors.plum, size: 14),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: WalletColors.plum, fontSize: 10, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class WalletPrimarySmallButton extends StatelessWidget {
  const WalletPrimarySmallButton({super.key, required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(colors: [WalletColors.coral, Color(0xFF8C5CF6)]),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class WalletPrimaryButton extends StatelessWidget {
  const WalletPrimaryButton({super.key, required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: WalletColors.deep, size: 18),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: WalletColors.deep, fontSize: 12, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class WalletGhostButton extends StatelessWidget {
  const WalletGhostButton({super.key, required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class WalletDarkSheet extends StatelessWidget {
  const WalletDarkSheet({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.paddingOf(context).bottom + 16),
      decoration: const BoxDecoration(
        color: Color(0xFF12101D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: child,
    );
  }
}

class WalletSheetHandle extends StatelessWidget {
  const WalletSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 4,
        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(999)),
      ),
    );
  }
}

class WalletHistoryTile extends StatelessWidget {
  const WalletHistoryTile({super.key, required this.row});

  final WalletHistoryRow row;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.title, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(row.subtitle, style: const TextStyle(color: Colors.white60, fontSize: 10.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Text(row.amount, style: const TextStyle(color: WalletColors.aqua, fontSize: 12, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
