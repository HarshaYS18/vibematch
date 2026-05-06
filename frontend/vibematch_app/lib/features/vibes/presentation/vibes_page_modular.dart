import 'package:flutter/material.dart';

import '../../social/widgets/friends_invite_sheet.dart';
import '../controllers/vibes_controller.dart';
import '../models/vibe_models.dart';
import 'pages/create_vibe_page_modular.dart';
import 'pages/vibe_detail_page_modular.dart';
import 'pages/vibes_settings_page.dart';
import 'widgets/vibe_card_modular.dart';

class VibesPage extends StatefulWidget {
  const VibesPage({super.key});

  @override
  State<VibesPage> createState() => _VibesPageState();
}

class _VibesPageState extends State<VibesPage> {
  final VibesController _controller = VibesController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _showAction(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF251538),
        ),
      );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VibesSettingsPage(
          whoCanMention: _controller.whoCanMention,
          whoCanComment: _controller.whoCanComment,
          onMentionChanged: (value) {
            _controller.setWhoCanMention(value);
          },
          onCommentChanged: (value) {
            _controller.setWhoCanComment(value);
          },
        ),
      ),
    );
  }

  void _openCreateVibe() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateVibePageModular(
          canUseMentionAllToday: _controller.canUseMentionAllToday,
          onPublish: (newVibe) {
            _controller.publishVibe(newVibe);
            _showAction('Vibe published locally. Backend API will connect later.');
          },
        ),
      ),
    );
  }

  void _openVibeDetail(VibeItem vibe) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VibeDetailPageModular(
          vibe: vibe,
          onCommentAdded: () => _controller.incrementCommentCount(vibe),
        ),
      ),
    );
  }

  void _openShareSheet(VibeItem vibe) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (_) => FriendsInviteSheet(
        title: 'Share ${vibe.authorName}\'s Vibe',
        actionLabel: 'Send',
        completedLabel: 'Sent',
        onInvite: (friend) {
          _showAction('Vibe sent to ${friend.displayName}');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleVibes = _controller.visibleVibes;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Vibes',
                        style: TextStyle(
                          color: Color(0xFF251538),
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.7,
                        ),
                      ),
                    ),
                    _RoundIconButton(
                      icon: Icons.settings_rounded,
                      onTap: _openSettings,
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  scrollDirection: Axis.horizontal,
                  itemCount: _controller.filters.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 9),
                  itemBuilder: (context, index) {
                    final filter = _controller.filters[index];
                    final selected = filter == _controller.selectedFilter;

                    return InkWell(
                      onTap: () => _controller.selectFilter(filter),
                      borderRadius: BorderRadius.circular(99),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFF251538) : Colors.white,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: selected ? const Color(0xFF251538) : const Color(0xFFECE2D8)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF251538).withValues(alpha: selected ? 0.10 : 0.04),
                              blurRadius: 14,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            filter,
                            style: TextStyle(
                              color: selected ? Colors.white : const Color(0xFF7A6B86),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (visibleVibes.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyVibesState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 116),
                sliver: SliverList.separated(
                  itemCount: visibleVibes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final vibe = visibleVibes[index];
                    return VibeCardModular(
                      vibe: vibe,
                      onProfileTap: () => _showAction('${vibe.authorName} profile will open.'),
                      onLikeTap: () => _controller.toggleLike(vibe),
                      onCommentTap: () => _openVibeDetail(vibe),
                      onShareTap: () => _openShareSheet(vibe),
                      onMoreTap: () => _showAction('Vibe options will open.'),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateVibe,
        backgroundColor: const Color(0xFF251538),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text('Create Vibe', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFECE2D8)),
          boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 7))],
        ),
        child: Icon(icon, color: const Color(0xFF251538)),
      ),
    );
  }
}

class _EmptyVibesState extends StatelessWidget {
  const _EmptyVibesState();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No Vibes here yet',
        style: TextStyle(color: Color(0xFF7B6A86), fontWeight: FontWeight.w800),
      ),
    );
  }
}
