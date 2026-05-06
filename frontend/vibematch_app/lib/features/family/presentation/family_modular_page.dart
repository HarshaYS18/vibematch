import 'package:flutter/material.dart';

import 'controllers/family_controller.dart';
import 'sheets/family_level_details_sheet.dart';
import 'widgets/family_channel_tabs.dart';
import 'widgets/family_chat_section.dart';
import 'widgets/family_empty_state.dart';
import 'widgets/family_header_card.dart';
import 'widgets/family_member_strip.dart';
import 'widgets/family_redesign_shared.dart';
import 'widgets/family_vibes_section.dart';

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
        body: SafeArea(
          child: FamilyEmptyState(
            onCreateFamily: () => _controller.createFamily(name: 'Aurora Circle', minimumVipLabel: 'VIP 5'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: FamilyRedesignColors.page,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: FamilyHeaderCard(
                profile: _controller.profile,
                level: _controller.levelProgress,
                exp: _controller.expBreakdown,
                onBack: () => Navigator.pop(context),
                onShare: () => _toast('Family share card will open here.'),
                onRewards: () => _toast('Family rewards will open here.'),
                onOptions: () => _toast('Family options sheet will open here.'),
                onLevelTap: _openLevelDetails,
              ),
            ),
            SliverToBoxAdapter(
              child: FamilyMemberStrip(
                members: _controller.members,
                totalCount: _controller.members.length,
                onOpenMembers: () => _toast('Full family member page will open here.'),
                onInvite: () => _toast('Invite member flow will open here.'),
              ),
            ),
            SliverToBoxAdapter(
              child: FamilyChannelTabs(
                selected: _controller.selectedTab,
                canPost: _controller.canPostFamilyVibe,
                onChanged: _controller.selectTab,
                onPost: _controller.postFamilyVibe,
              ),
            ),
            if (_controller.selectedTab.name == 'vibes')
              FamilyVibesSection(vibes: _controller.vibes)
            else
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
