import 'package:flutter/material.dart';

import '../../models/family_ui_models.dart';
import 'family_redesign_shared.dart';

class FamilyRankedMemberStrip extends StatelessWidget {
  const FamilyRankedMemberStrip({super.key, required this.members, required this.totalCount, required this.onOpenMembers, required this.onInvite});

  final List<FamilyMemberUiModel> members;
  final int totalCount;
  final VoidCallback onOpenMembers;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final preview = members.take(7).toList();
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: FamilyRedesignColors.line),
        boxShadow: [BoxShadow(color: FamilyRedesignColors.ink.withValues(alpha: 0.05), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onOpenMembers,
            borderRadius: BorderRadius.circular(14),
            child: Row(
              children: [
                const Icon(Icons.military_tech_rounded, color: FamilyRedesignColors.gold, size: 22),
                const SizedBox(width: 8),
                const Expanded(child: Text('Clan Roster', style: TextStyle(color: FamilyRedesignColors.ink, fontSize: 18, fontWeight: FontWeight.w900))),
                Text('$totalCount members', style: const TextStyle(color: FamilyRedesignColors.soft, fontSize: 12, fontWeight: FontWeight.w800)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, color: FamilyRedesignColors.ink),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 142,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: preview.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                if (index == preview.length) return _InviteCard(onTap: onInvite);
                return _RankedMemberCard(member: preview[index], rank: index + 1);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RankedMemberCard extends StatelessWidget {
  const _RankedMemberCard({required this.member, required this.rank});

  final FamilyMemberUiModel member;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final rankColor = rank == 1 ? FamilyRedesignColors.gold : rank == 2 ? FamilyRedesignColors.violet : FamilyRedesignColors.aqua;
    return Container(
      width: 92,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
      decoration: BoxDecoration(color: FamilyRedesignColors.page, borderRadius: BorderRadius.circular(22), border: Border.all(color: rankColor.withValues(alpha: 0.22))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(width: 22, height: 22, decoration: BoxDecoration(color: rankColor, shape: BoxShape.circle), child: Center(child: Text('$rank', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)))),
              const Spacer(),
              Icon(member.role == FamilyRole.owner ? Icons.workspace_premium_rounded : member.role == FamilyRole.admin ? Icons.shield_rounded : Icons.person_rounded, color: rankColor, size: 16),
            ],
          ),
          const SizedBox(height: 5),
          FamilyGradientAvatar(text: member.avatarText, colors: member.avatarGradient, size: 40),
          const SizedBox(height: 5),
          SizedBox(
            height: 28,
            child: Text(member.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: FamilyRedesignColors.ink, fontSize: 10.2, height: 1.05, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 2),
          Text(compactFamilyNumber(member.contributionExp), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: FamilyRedesignColors.soft, fontSize: 9.5, height: 1, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 92,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(color: const Color(0xFF100A18), borderRadius: BorderRadius.circular(22)),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_add_alt_1_rounded, color: FamilyRedesignColors.neon, size: 30),
            SizedBox(height: 8),
            Text('Invite', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}
