import 'package:flutter/material.dart';

import '../../models/family_ui_models.dart';
import 'family_redesign_shared.dart';

class FamilyMemberStrip extends StatelessWidget {
  const FamilyMemberStrip({
    super.key,
    required this.members,
    required this.totalCount,
    required this.onOpenMembers,
    required this.onInvite,
  });

  final List<FamilyMemberUiModel> members;
  final int totalCount;
  final VoidCallback onOpenMembers;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final preview = members.take(6).toList();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.all(14),
      decoration: FamilyRedesignDecor.panel(24),
      child: Column(
        children: [
          InkWell(
            onTap: onOpenMembers,
            borderRadius: BorderRadius.circular(14),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Family Members', style: TextStyle(color: FamilyRedesignColors.ink, fontSize: 18, fontWeight: FontWeight.w900)),
                ),
                FamilySmallPill(icon: Icons.groups_rounded, label: '$totalCount'),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded, color: FamilyRedesignColors.ink),
              ],
            ),
          ),
          const SizedBox(height: 13),
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: preview.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                if (index == preview.length) return _InviteBubble(onTap: onInvite);
                return _MemberBubble(member: preview[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberBubble extends StatelessWidget {
  const _MemberBubble({required this.member});

  final FamilyMemberUiModel member;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FamilyGradientAvatar(text: member.avatarText, colors: member.avatarGradient, size: 58),
          const SizedBox(height: 7),
          SizedBox(
            height: 27,
            child: Text(
              member.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: FamilyRedesignColors.soft, fontSize: 10.5, height: 1.06, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteBubble extends StatelessWidget {
  const _InviteBubble({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(color: FamilyRedesignColors.page, shape: BoxShape.circle),
              child: const Icon(Icons.add_rounded, color: FamilyRedesignColors.ink, size: 34),
            ),
            const SizedBox(height: 7),
            const SizedBox(
              height: 27,
              child: Text('Invite', textAlign: TextAlign.center, style: TextStyle(color: FamilyRedesignColors.soft, fontSize: 10.5, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}
