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
    final subtitleText = subtitle;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: SuperPowerDesign.shell(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 4, height: 24, decoration: BoxDecoration(gradient: SuperPowerDesign.goldGradient, borderRadius: BorderRadius.circular(99))),
            const SizedBox(width: 8),
            Expanded(child: Text(title.toUpperCase(), style: const TextStyle(color: SuperPowerDesign.text, fontSize: 13.2, fontWeight: FontWeight.w900, letterSpacing: 0.8))),
            ?trailing,
          ]),
          if (subtitleText != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(subtitleText, style: const TextStyle(color: SuperPowerDesign.muted, fontSize: 10.8, height: 1.25, fontWeight: FontWeight.w700)),
            ),
          ],
          const SizedBox(height: 12),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            height: 62,
            decoration: SuperPowerDesign.glassStrip(accent: accent),
            child: Row(children: [
              Container(width: 5, height: double.infinity, decoration: BoxDecoration(color: accent, borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)))),
              const SizedBox(width: 9),
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(width: 39, height: 39, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: accent.withValues(alpha: 0.48)), color: accent.withValues(alpha: 0.10))),
                  Container(width: 25, height: 25, decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: 0.13))),
                  Icon(icon, color: accent, size: 18),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SuperPowerDesign.text, fontSize: 12.7, fontWeight: FontWeight.w900, letterSpacing: -0.1)),
                const SizedBox(height: 3),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SuperPowerDesign.muted, fontSize: 10.4, fontWeight: FontWeight.w700)),
              ])),
              const SizedBox(width: 8),
              trailing ?? Icon(Icons.keyboard_arrow_right_rounded, color: accent, size: 22),
              const SizedBox(width: 9),
            ]),
          ),
        ),
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
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withValues(alpha: 0.20), color.withValues(alpha: 0.06)]),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.46)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.25)),
    );
  }
}
