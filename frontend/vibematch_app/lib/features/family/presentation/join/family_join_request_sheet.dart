import 'package:flutter/material.dart';

import '../../models/family_ui_models.dart';
import '../widgets/family_redesign_shared.dart';

class FamilyJoinRequestSheet extends StatelessWidget {
  const FamilyJoinRequestSheet({
    super.key,
    required this.family,
    required this.onCreateFamily,
    required this.onJoinFamily,
  });

  final FamilyProfileUiModel family;
  final VoidCallback onCreateFamily;
  final VoidCallback onJoinFamily;

  @override
  Widget build(BuildContext context) {
    return FamilySheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [FamilyRedesignColors.ink, FamilyRedesignColors.coral, FamilyRedesignColors.gold]),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(family.avatarText, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(family.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: FamilyRedesignColors.ink, fontSize: 21, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('${family.id} · ${family.rankLabel}', style: const TextStyle(color: FamilyRedesignColors.soft, fontSize: 12, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('You are not in any family', style: TextStyle(color: FamilyRedesignColors.ink, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text(
            'Create your own family or request to join this family. Join requests are sent as system notifications to the owner and admins.',
            style: TextStyle(color: FamilyRedesignColors.soft, height: 1.35, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          _FlowInfo(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: FamilySecondaryButton(label: 'Create Family', onTap: onCreateFamily)),
              const SizedBox(width: 10),
              Expanded(child: FamilyPrimaryButton(label: 'Join Family', onTap: onJoinFamily)),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlowInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: FamilyRedesignColors.page, borderRadius: BorderRadius.circular(18)),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoLine(icon: Icons.notifications_active_rounded, text: 'Join request is sent to all owners/admins.'),
          SizedBox(height: 8),
          _InfoLine(icon: Icons.check_circle_rounded, text: 'Accept: you join and everyone gets a system notification.'),
          SizedBox(height: 8),
          _InfoLine(icon: Icons.cancel_rounded, text: 'Reject: you get a system notification with the rejecting admin/owner.'),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: FamilyRedesignColors.gold, size: 17),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(color: FamilyRedesignColors.soft, height: 1.25, fontSize: 12, fontWeight: FontWeight.w800))),
      ],
    );
  }
}
