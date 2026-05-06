import 'package:flutter/material.dart';

import '../../models/family_ui_models.dart';
import '../widgets/family_redesign_shared.dart';

class FamilyInviteFlowPage extends StatefulWidget {
  const FamilyInviteFlowPage({
    super.key,
    required this.familyName,
    required this.actorType,
    required this.friends,
    required this.selectedUserIds,
    required this.onToggleFriend,
    required this.onSendInvites,
  });

  final String familyName;
  final FamilyInviteActorType actorType;
  final List<FamilyInviteFriendUiModel> friends;
  final Set<String> selectedUserIds;
  final ValueChanged<FamilyInviteFriendUiModel> onToggleFriend;
  final VoidCallback onSendInvites;

  @override
  State<FamilyInviteFlowPage> createState() => _FamilyInviteFlowPageState();
}

class _FamilyInviteFlowPageState extends State<FamilyInviteFlowPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _send() {
    if (widget.selectedUserIds.isEmpty) return;
    widget.onSendInvites();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final friends = widget.friends.where((friend) {
      final text = '${friend.name} ${friend.statusLabel}'.toLowerCase();
      return text.contains(_query.toLowerCase());
    }).toList();

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
                      child: Text('Invite to Family', style: TextStyle(color: FamilyRedesignColors.ink, fontSize: 24, fontWeight: FontWeight.w900)),
                    ),
                    _SendInviteButton(count: widget.selectedUserIds.length, onTap: _send),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _InviteRuleCard(familyName: widget.familyName, actorType: widget.actorType, count: widget.selectedUserIds.length),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'Search mutual friends',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              sliver: SliverList.separated(
                itemCount: friends.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final friend = friends[index];
                  return FamilyInviteFriendTile(
                    friend: friend,
                    selected: widget.selectedUserIds.contains(friend.userId),
                    selectionDisabled: !widget.selectedUserIds.contains(friend.userId) && widget.selectedUserIds.length >= 10,
                    onTap: () {
                      widget.onToggleFriend(friend);
                      setState(() {});
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SendInviteButton extends StatelessWidget {
  const _SendInviteButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = count > 0;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: enabled ? FamilyRedesignColors.ink : const Color(0xFFE9E1DB),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Text(
            count == 0 ? 'Send' : 'Send $count',
            style: TextStyle(color: enabled ? Colors.white : FamilyRedesignColors.soft, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

class _InviteRuleCard extends StatelessWidget {
  const _InviteRuleCard({required this.familyName, required this.actorType, required this.count});

  final String familyName;
  final FamilyInviteActorType actorType;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF100A18),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFFD36A).withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: const Color(0xFFFFD36A).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(15)),
            child: const Icon(Icons.mark_email_unread_rounded, color: Color(0xFFFFD36A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invite up to 10 friends · $count selected', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  'Invites to $familyName go through Inbox and expire in 24 hours. ${actorType.approvalCopy}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.62), height: 1.25, fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FamilyInviteFriendTile extends StatelessWidget {
  const FamilyInviteFriendTile({
    super.key,
    required this.friend,
    required this.selected,
    required this.selectionDisabled,
    required this.onTap,
  });

  final FamilyInviteFriendUiModel friend;
  final bool selected;
  final bool selectionDisabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = !friend.canInvite || selectionDisabled;
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: selected ? FamilyRedesignColors.neon : FamilyRedesignColors.line, width: selected ? 1.4 : 1),
          boxShadow: [BoxShadow(color: FamilyRedesignColors.ink.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Row(
          children: [
            _SelectionCircle(selected: selected, disabled: disabled),
            const SizedBox(width: 12),
            FamilyGradientAvatar(text: friend.avatarText, colors: friend.avatarGradient, size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(friend.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: FamilyRedesignColors.ink, fontSize: 15, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Text(friend.canInvite ? friend.statusLabel : 'Already in a family', style: TextStyle(color: friend.canInvite ? FamilyRedesignColors.soft : FamilyRedesignColors.coral, fontSize: 12, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            if (selected) const Icon(Icons.done_rounded, color: FamilyRedesignColors.neon),
          ],
        ),
      ),
    );
  }
}

class _SelectionCircle extends StatelessWidget {
  const _SelectionCircle({required this.selected, required this.disabled});

  final bool selected;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? FamilyRedesignColors.neon : Colors.transparent,
        border: Border.all(color: disabled ? const Color(0xFFD8D1CB) : selected ? FamilyRedesignColors.neon : FamilyRedesignColors.soft, width: 2),
      ),
      child: selected ? const Icon(Icons.check_rounded, color: FamilyRedesignColors.ink, size: 16) : null,
    );
  }
}
