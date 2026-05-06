import 'package:flutter/material.dart';

import '../../models/family_ui_models.dart';
import 'family_redesign_shared.dart';

class FamilyClanChannelDock extends StatelessWidget {
  const FamilyClanChannelDock({super.key, required this.selected, required this.canPost, required this.onChanged, required this.onPost});

  final FamilyChannelTab selected;
  final bool canPost;
  final ValueChanged<FamilyChannelTab> onChanged;
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF100A18),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Expanded(child: _DockTab(icon: Icons.auto_awesome_rounded, label: 'Vibes', active: selected == FamilyChannelTab.vibes, onTap: () => onChanged(FamilyChannelTab.vibes))),
          const SizedBox(width: 8),
          Expanded(child: _DockTab(icon: Icons.forum_rounded, label: 'Chat', active: selected == FamilyChannelTab.chat, onTap: () => onChanged(FamilyChannelTab.chat))),
          if (selected == FamilyChannelTab.vibes && canPost) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onPost,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: FamilyRedesignColors.neon, borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.add_rounded, color: FamilyRedesignColors.ink, size: 28),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DockTab extends StatelessWidget {
  const _DockTab({required this.icon, required this.label, required this.active, required this.onTap});

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 48,
        decoration: BoxDecoration(
          color: active ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: active ? FamilyRedesignColors.gold.withValues(alpha: 0.34) : Colors.transparent),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? FamilyRedesignColors.gold : Colors.white.withValues(alpha: 0.55), size: 18),
            const SizedBox(width: 7),
            Text(label, style: TextStyle(color: active ? Colors.white : Colors.white.withValues(alpha: 0.62), fontSize: 13, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}
