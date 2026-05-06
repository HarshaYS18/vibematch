import 'package:flutter/material.dart';

import '../models/family_ui_models.dart';
import 'controllers/family_controller.dart';
import 'family_list_page.dart';
import 'invite/family_invite_flow_page.dart';
import 'rankings/family_ranking_module.dart';
import 'sheets/create_family_sheet.dart';
import 'sheets/disband_family_confirmation_sheet.dart';
import 'sheets/family_actions_sheet.dart';
import 'sheets/family_level_details_sheet.dart';
import 'widgets/family_chat_section.dart';
import 'widgets/family_clan_hero.dart';
import 'widgets/family_ranked_member_strip.dart';
import 'widgets/family_redesign_shared.dart';

class FamilyModularPage extends StatefulWidget {
  const FamilyModularPage({super.key});

  @override
  State<FamilyModularPage> createState() => _FamilyModularPageState();
}

class _FamilyModularPageState extends State<FamilyModularPage> {
  late final FamilyController _controller = FamilyController()..addListener(_sync);
  final TextEditingController _chatController = TextEditingController();

  @override
  void dispose() {
    _controller.removeListener(_sync);
    _controller.dispose();
    _chatController.dispose();
    super.dispose();
  }

  void _sync() {
    if (mounted) setState(() {});
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: FamilyRedesignColors.ink, content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800))));
  }

  void _openInviteFlow() {
    _controller.clearInviteSelection();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FamilyInviteFlowPage(
          familyName: _controller.profile.name,
          actorType: _controller.inviteActorType,
          friends: _controller.inviteFriends,
          selectedUserIds: _controller.selectedInviteUserIds,
          onToggleFriend: _controller.toggleInviteSelection,
          onSendInvites: _sendFamilyInvites,
        ),
      ),
    );
  }

  void _sendFamilyInvites() {
    final selected = _controller.selectedInviteFriends();
    final count = selected.length;
    final flow = _controller.inviteActorType.needsOwnerApprovalAfterAccept
        ? 'When a user accepts, owners/admins will receive an approval request. Approve = join, reject = invite link invalid.'
        : 'When a user accepts, they join directly and owners/admins receive a system notification.';
    _controller.markInvitesSent();
    _toast('Sent $count family invite${count == 1 ? '' : 's'} through Inbox. $flow');
  }

  void _openFamilyList() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FamilyListPage(
          members: _controller.members,
          onInvite: _openInviteFlow,
        ),
      ),
    );
  }

  void _openCreateFamily() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateFamilySheet(
        onCreate: (name, minimumVipLabel) {
          Navigator.pop(context);
          _controller.createFamily(name: name, minimumVipLabel: minimumVipLabel);
        },
      ),
    );
  }

  void _openRankedFamily(FamilyRankUiModel family) {
    _controller.openFamilyFromRanking(family);
    _toast('Opened ${family.name}. Join request can be sent from the ranking list.');
  }

  void _requestJoinRankedFamily(FamilyRankUiModel family) {
    _controller.requestJoinFamily(family: family);
    _toast('System notification sent to ${family.name} owner/admins: you want to join this family.');
  }

  void _openDisbandConfirmation() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DisbandFamilyConfirmationSheet(
        familyName: _controller.profile.name,
        onConfirm: () {
          Navigator.pop(context);
          _controller.disbandFamily();
          _toast('Family deleted. Members have been released from the family.');
        },
      ),
    );
  }

  void _openActions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => FamilyActionsSheet(
        isOwner: _controller.isOwner,
        adminCount: _controller.adminCount,
        adminCapacity: _controller.adminCapacity,
        onSetAdmins: () {
          Navigator.pop(context);
          _toast('Set admins sheet will open next.');
        },
        onExit: () {
          Navigator.pop(context);
          _controller.exitFamily();
        },
        onDisband: () {
          Navigator.pop(context);
          _openDisbandConfirmation();
        },
      ),
    );
  }

  void _openLevelDetails() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FamilyLevelDetailsSheet(level: _controller.levelProgress, exp: _controller.expBreakdown),
    );
  }

  void _sendChat() {
    _controller.sendMessage(_chatController.text);
    _chatController.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.hasFamily) {
      return FamilyRankingModule(
        rankings: _controller.rankings,
        joinRequestPending: _controller.joinRequestPending,
        onOpenFamily: _openRankedFamily,
        onJoinFamily: _requestJoinRankedFamily,
        onCreateFamily: _openCreateFamily,
      );
    }

    return Scaffold(
      backgroundColor: FamilyRedesignColors.page,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: FamilyClanHero(
                profile: _controller.profile,
                level: _controller.levelProgress,
                exp: _controller.expBreakdown,
                onBack: () => Navigator.pop(context),
                onInvite: _openInviteFlow,
                onRewards: () => _toast('Family rewards will open here.'),
                onOptions: _openActions,
                onLevelTap: _openLevelDetails,
              ),
            ),
            SliverToBoxAdapter(
              child: FamilyRankedMemberStrip(
                members: _controller.members,
                totalCount: _controller.members.length,
                onOpenMembers: _openFamilyList,
                onInvite: _openInviteFlow,
              ),
            ),
            SliverToBoxAdapter(
              child: FamilyChatSection(
                messages: _controller.messages,
                controller: _chatController,
                onSend: _sendChat,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
