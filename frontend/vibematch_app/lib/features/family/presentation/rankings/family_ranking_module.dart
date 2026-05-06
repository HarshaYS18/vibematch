import 'package:flutter/material.dart';

import '../../models/family_ui_models.dart';
import '../widgets/family_redesign_shared.dart';

class FamilyRankingModule extends StatelessWidget {
  const FamilyRankingModule({
    super.key,
    required this.rankings,
    required this.joinRequestPending,
    required this.onOpenFamily,
    required this.onJoinFamily,
    required this.onCreateFamily,
  });

  final List<FamilyRankUiModel> rankings;
  final bool joinRequestPending;
  final ValueChanged<FamilyRankUiModel> onOpenFamily;
  final ValueChanged<FamilyRankUiModel> onJoinFamily;
  final VoidCallback onCreateFamily;

  @override
  Widget build(BuildContext context) {
    final sortedRankings = [...rankings]..sort((a, b) => b.totalExp.compareTo(a.totalExp));

    return Scaffold(
      backgroundColor: FamilyRedesignColors.page,
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _RankingHeader(totalFamilies: sortedRankings.length)),
                SliverToBoxAdapter(child: _TopFamilyPodium(rankings: sortedRankings.take(3).toList(), onOpenFamily: onOpenFamily, onJoinFamily: onJoinFamily)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
                  sliver: SliverList.separated(
                    itemCount: sortedRankings.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final family = sortedRankings[index];
                      return FamilyRankTile(
                        family: family,
                        rank: index + 1,
                        joinRequestPending: joinRequestPending,
                        onOpen: () => onOpenFamily(family),
                        onJoin: () => onJoinFamily(family),
                      );
                    },
                  ),
                ),
              ],
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _CreateFamilyBar(onCreateFamily: onCreateFamily),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankingHeader extends StatelessWidget {
  const _RankingHeader({required this.totalFamilies});

  final int totalFamilies;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded, color: FamilyRedesignColors.ink)),
          const Expanded(child: Text('Family Rankings', style: TextStyle(color: FamilyRedesignColors.ink, fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -0.4))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), border: Border.all(color: FamilyRedesignColors.line)),
            child: Text('$totalFamilies families', style: const TextStyle(color: FamilyRedesignColors.soft, fontSize: 12, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _TopFamilyPodium extends StatelessWidget {
  const _TopFamilyPodium({required this.rankings, required this.onOpenFamily, required this.onJoinFamily});

  final List<FamilyRankUiModel> rankings;
  final ValueChanged<FamilyRankUiModel> onOpenFamily;
  final ValueChanged<FamilyRankUiModel> onJoinFamily;

  @override
  Widget build(BuildContext context) {
    if (rankings.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF100A18),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.emoji_events_rounded, color: FamilyRedesignColors.gold),
              SizedBox(width: 8),
              Text('Top Families by Total EXP', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: rankings.map((family) {
              final isTop = family.rank == 1;
              return Expanded(
                child: InkWell(
                  onTap: () => onOpenFamily(family),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    height: isTop ? 148 : 126,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: family.avatarGradient),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(width: 28, height: 28, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Center(child: Text('${family.rank}', style: const TextStyle(color: FamilyRedesignColors.ink, fontWeight: FontWeight.w900)))),
                        const SizedBox(height: 8),
                        Text(family.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.05, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Text(compactFamilyNumber(family.totalExp), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class FamilyRankTile extends StatelessWidget {
  const FamilyRankTile({
    super.key,
    required this.family,
    required this.rank,
    required this.joinRequestPending,
    required this.onOpen,
    required this.onJoin,
  });

  final FamilyRankUiModel family;
  final int rank;
  final bool joinRequestPending;
  final VoidCallback onOpen;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final rankColor = rank <= 3 ? FamilyRedesignColors.gold : FamilyRedesignColors.soft;
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: FamilyRedesignDecor.panel(24),
        child: Row(
          children: [
            SizedBox(width: 34, child: Text('$rank', textAlign: TextAlign.center, style: TextStyle(color: rankColor, fontSize: 17, fontWeight: FontWeight.w900))),
            const SizedBox(width: 8),
            FamilyGradientAvatar(text: family.avatarText, colors: family.avatarGradient, size: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(family.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: FamilyRedesignColors.ink, fontSize: 15.5, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      FamilySmallPill(icon: Icons.groups_rounded, label: '${family.memberCount}/${family.maxMembers}'),
                      FamilySmallPill(icon: Icons.auto_graph_rounded, label: compactFamilyNumber(family.totalExp)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: joinRequestPending ? null : onJoin,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: joinRequestPending ? const Color(0xFFE9E1DB) : FamilyRedesignColors.neon, borderRadius: BorderRadius.circular(16)),
                child: Text(joinRequestPending ? 'Pending' : 'Join', style: const TextStyle(color: FamilyRedesignColors.ink, fontSize: 12, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateFamilyBar extends StatelessWidget {
  const _CreateFamilyBar({required this.onCreateFamily});

  final VoidCallback onCreateFamily;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF100A18),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFD36A).withValues(alpha: 0.16)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 22, offset: const Offset(0, 10))],
      ),
      child: Row(
        children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: FamilyRedesignColors.gold.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.add_business_rounded, color: FamilyRedesignColors.gold)),
          const SizedBox(width: 10),
          const Expanded(child: Text('Start your own family', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900))),
          FamilyPrimaryButton(label: 'Create', onTap: onCreateFamily),
        ],
      ),
    );
  }
}
