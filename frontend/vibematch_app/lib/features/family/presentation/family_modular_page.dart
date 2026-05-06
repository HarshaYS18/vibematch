import 'package:flutter/material.dart';

import 'controllers/family_controller.dart';
import 'sheets/create_family_sheet.dart';
import 'sheets/family_actions_sheet.dart';
import 'sheets/family_level_details_sheet.dart';
import 'widgets/family_chat_section.dart';
import 'widgets/family_clan_hero.dart';
import 'widgets/family_empty_state.dart';
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
          _controller.disbandFamily();
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
      return Scaffold(
        backgroundColor: FamilyRedesignColors.page,
        body: SafeArea(child: FamilyEmptyState(onCreateFamily: _openCreateFamily)),
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
                onShare: () => _toast('Family share card will open here.'),
                onRewards: () => _toast('Family rewards will open here.'),
                onOptions: _openActions,
                onLevelTap: _openLevelDetails,
              ),
            ),
            SliverToBoxAdapter(
              child: FamilyRankedMemberStrip(
                members: _controller.members,
                totalCount: _controller.members.length,
                onOpenMembers: () => _toast('Full family member page will open here.'),
                onInvite: () => _toast('Invite member flow will open here.'),
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
