import 'package:flutter/material.dart';

import '../models/family_ui_models.dart';
import 'widgets/family_redesign_shared.dart';

class FamilyListPage extends StatefulWidget {
  const FamilyListPage({super.key, required this.members, required this.onInvite});

  final List<FamilyMemberUiModel> members;
  final VoidCallback onInvite;

  @override
  State<FamilyListPage> createState() => _FamilyListPageState();
}

class _FamilyListPageState extends State<FamilyListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleMembers = widget.members.where((member) => member.name.toLowerCase().contains(_query.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: FamilyRedesignColors.page,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded, color: FamilyRedesignColors.ink),
                    ),
                    const Expanded(
                      child: Text('Family Members', style: TextStyle(color: FamilyRedesignColors.ink, fontSize: 24, fontWeight: FontWeight.w900)),
                    ),
                    InkWell(
                      onTap: widget.onInvite,
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(color: FamilyRedesignColors.ink, borderRadius: BorderRadius.circular(18)),
                        child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'Search family member',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Text('All members (${visibleMembers.length})', style: const TextStyle(color: FamilyRedesignColors.soft, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    const Icon(Icons.sort_rounded, size: 18, color: FamilyRedesignColors.ink),
                    const SizedBox(width: 4),
                    const Text('Contribution', style: TextStyle(color: FamilyRedesignColors.ink, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              sliver: SliverList.separated(
                itemCount: visibleMembers.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) => _FamilyMemberRow(member: visibleMembers[index], rank: index + 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FamilyMemberRow extends StatelessWidget {
  const _FamilyMemberRow({required this.member, required this.rank});

  final FamilyMemberUiModel member;
  final int rank;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: FamilyRedesignDecor.panel(22),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text('$rank', textAlign: TextAlign.center, style: const TextStyle(color: FamilyRedesignColors.gold, fontSize: 16, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 8),
          FamilyGradientAvatar(text: member.avatarText, colors: member.avatarGradient, size: 54),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: FamilyRedesignColors.ink, fontSize: 15, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                FamilyRoleChip(role: member.role),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _ContributionBadge(value: compactFamilyNumber(member.contributionExp)),
        ],
      ),
    );
  }
}

class _ContributionBadge extends StatelessWidget {
  const _ContributionBadge({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 62),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FamilyRedesignColors.violet.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_graph_rounded, color: FamilyRedesignColors.violet, size: 14),
          const SizedBox(width: 4),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: FamilyRedesignColors.soft, fontSize: 11, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
