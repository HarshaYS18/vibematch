import 'package:flutter/material.dart';

import '../../models/family_ui_models.dart';
import 'family_redesign_shared.dart';

class FamilyChannelTabs extends StatelessWidget {
  const FamilyChannelTabs({
    super.key,
    required this.selected,
    required this.canPost,
    required this.onChanged,
    required this.onPost,
  });

  final FamilyChannelTab selected;
  final bool canPost;
  final ValueChanged<FamilyChannelTab> onChanged;
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: [
          _TabButton(label: FamilyChannelTab.vibes.label, active: selected == FamilyChannelTab.vibes, onTap: () => onChanged(FamilyChannelTab.vibes)),
          const SizedBox(width: 8),
          _TabButton(label: FamilyChannelTab.chat.label, active: selected == FamilyChannelTab.chat, onTap: () => onChanged(FamilyChannelTab.chat)),
          const Spacer(),
          if (selected == FamilyChannelTab.vibes && canPost)
            InkWell(
              onTap: onPost,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: FamilyRedesignColors.neon, borderRadius: BorderRadius.circular(16)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_rounded, color: FamilyRedesignColors.ink, size: 18),
                    SizedBox(width: 6),
                    Text('Post', style: TextStyle(color: FamilyRedesignColors.ink, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: active ? FamilyRedesignColors.ink : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? FamilyRedesignColors.ink : FamilyRedesignColors.line),
        ),
        child: Text(label, style: TextStyle(color: active ? Colors.white : FamilyRedesignColors.soft, fontWeight: FontWeight.w900)),
      ),
    );
  }
}
