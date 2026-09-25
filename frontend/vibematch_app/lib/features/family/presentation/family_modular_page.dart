import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/family_ui_models.dart';
import 'controllers/family_controller.dart';
import 'family_list_page.dart';
import 'invite/family_invite_flow_page.dart';
import 'rankings/family_ranking_module.dart';
import 'sheets/create_family_sheet.dart';
import 'sheets/disband_family_confirmation_sheet.dart';
import 'sheets/family_actions_sheet.dart';
import 'sheets/family_level_details_sheet.dart';
import 'sheets/set_family_admins_sheet.dart';
import 'widgets/family_chat_section.dart';
import 'widgets/family_clan_hero.dart';
import 'widgets/family_ranked_member_strip.dart';
import 'widgets/family_redesign_shared.dart';

class FamilyModularPage extends ConsumerStatefulWidget {
  const FamilyModularPage({
    super.key,
    this.openCurrentFamily = false,
    this.initialFamilyProfile,
    this.initialIsOwner = false,
    this.initialIsAdmin = false,
  });

  final bool openCurrentFamily;
  final FamilyProfileUiModel? initialFamilyProfile;
  final bool initialIsOwner;
  final bool initialIsAdmin;

  @override
  ConsumerState<FamilyModularPage> createState() => _FamilyModularPageState();
}

class _FamilyModularPageState extends ConsumerState<FamilyModularPage> {
  late final FamilyControllerArgs _providerArgs;
  final TextEditingController _chatController = TextEditingController();

  FamilyController get _controller =>
      ref.read(familyControllerProvider(_providerArgs).notifier);

  @override
  void initState() {
    super.initState();
    _providerArgs = FamilyControllerArgs(
      initialHasFamily: widget.openCurrentFamily,
      initialProfile: widget.initialFamilyProfile,
      initialIsOwner: widget.initialIsOwner,
      initialIsAdmin: widget.initialIsAdmin,
    );
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: FamilyRedesignColors.ink,
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      );
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
    _toast(
      'Sent $count family invite${count == 1 ? '' : 's'} through Inbox. $flow',
    );
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
          _controller.createFamily(
            name: name,
            minimumVipLabel: minimumVipLabel,
          );
        },
      ),
    );
  }

  void _openRankedFamily(FamilyRankUiModel family) {
    _controller.openFamilyFromRanking(family);
    _toast(
      'Opened ${family.name}. Join request can be sent from the ranking list.',
    );
  }

  void _requestJoinRankedFamily(FamilyRankUiModel family) {
    _controller.requestJoinFamily(family: family);
    _toast(
      'System notification sent to ${family.name} owner/admins: you want to join this family.',
    );
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

  void _openSetAdminsSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SetFamilyAdminsSheet(
        members: _controller.members,
        adminCapacity: _controller.adminCapacity,
        onSave: (selectedAdminIds) {
          _controller.applyAdminSelection(selectedAdminIds);
          _toast(
            'Family admins updated. ${selectedAdminIds.length}/${_controller.adminCapacity} selected.',
          );
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
          _openSetAdminsSheet();
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
      builder: (_) => FamilyLevelDetailsSheet(
        level: _controller.levelProgress,
        exp: _controller.expBreakdown,
      ),
    );
  }

  Future<void> _sendChat() async {
    final text = _chatController.text;
    if (text.trim().isEmpty) return;
    final sent = await _controller.sendMessage(text);
    if (!mounted) return;
    if (sent) {
      _chatController.clear();
    } else {
      _toast(_controller.backendError ?? 'Could not send family message.');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(familyControllerProvider(_providerArgs));
    if (!_controller.hasFamily) {
      return FamilyRankingModule(
        rankings: _controller.rankings,
        selectedPeriod: _controller.selectedRankingPeriod,
        loading: _controller.loadingRankings,
        joinRequestPending: _controller.joinRequestPending,
        onPeriodChanged: _controller.setRankingPeriod,
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
                onSend: () => unawaited(_sendChat()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
