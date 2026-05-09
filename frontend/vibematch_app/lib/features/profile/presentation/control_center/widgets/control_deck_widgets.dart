import 'package:flutter/material.dart';

import 'super_power_design.dart';

class ControlDeckShell extends StatelessWidget {
  const ControlDeckShell({super.key, required this.title, this.subtitle, required this.children, this.trailing});

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: SuperPowerDesign.shell(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(title, style: const TextStyle(color: SuperPowerDesign.text, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: -0.2))),
            if (trailing != null) trailing!,
          ]),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle!, style: const TextStyle(color: SuperPowerDesign.muted, fontSize: 11, height: 1.25, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class ControlDeckRow extends StatelessWidget {
  const ControlDeckRow({super.key, required this.icon, required this.title, required this.subtitle, required this.accent, required this.onTap, this.trailing});

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: SuperPowerDesign.obsidian, borderRadius: BorderRadius.circular(17), border: Border.all(color: SuperPowerDesign.stroke)),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: accent.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(13), border: Border.all(color: accent.withValues(alpha: 0.32))),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SuperPowerDesign.text, fontSize: 12.8, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SuperPowerDesign.muted, fontSize: 10.6, fontWeight: FontWeight.w700)),
          ])),
          const SizedBox(width: 8),
          trailing ?? const Icon(Icons.chevron_right_rounded, color: SuperPowerDesign.muted, size: 20),
        ]),
      ),
    );
  }
}

class ControlDeckPill extends StatelessWidget {
  const ControlDeckPill({super.key, required this.label, this.color = SuperPowerDesign.gold});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: 0.42))),
      child: Text(label, style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w900)),
    );
  }
}
