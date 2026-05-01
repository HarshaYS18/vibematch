import 'package:flutter/material.dart';

import '../controllers/vibes_feed_controller.dart';
import '../data/vibes_mock_data.dart';
import '../models/vibe_item.dart';
import 'create_vibe_page.dart';
import 'vibe_comments_page.dart';
import 'widgets/vibe_card.dart';
import 'widgets/vibes_empty_state.dart';
import 'widgets/vibes_filter_chips.dart';
import 'widgets/vibes_header.dart';

class VibesModularPage extends StatefulWidget {
  const VibesModularPage({super.key});

  @override
  State<VibesModularPage> createState() => _VibesModularPageState();
}

class _VibesModularPageState extends State<VibesModularPage> {
  late final ScrollController _scrollController;
  late final VibesFeedController _feedController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
    _feedController = VibesFeedController(initialVibes: VibesMockData.vibes)
      ..addListener(_handleFeedChanged);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _feedController.removeListener(_handleFeedChanged);
    _feedController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    _feedController.loadMoreIfNeeded(
      pixels: _scrollController.position.pixels,
      maxScrollExtent: _scrollController.position.maxScrollExtent,
    );
  }

  void _handleFeedChanged() {
    if (mounted) setState(() {});
  }

  void _showAction(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF251538),
        ),
      );
  }

  void _openCreateVibe() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateVibePage(
          onPublish: (newVibe) {
            _feedController.publishLocalVibe(newVibe);
            _showAction('Vibe published locally. Backend API will connect later.');
          },
        ),
      ),
    );
  }

  void _openComments(VibeItem vibe) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VibeCommentsPage(vibe: vibe),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleVibes = _feedController.visibleVibes;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: VibesHeader(onCreateTap: _openCreateVibe),
            ),
            SliverToBoxAdapter(
              child: VibesFilterChips(
                filters: VibesMockData.filters,
                selectedFilter: _feedController.selectedFilter,
                onFilterSelected: _feedController.selectFilter,
              ),
            ),
            if (visibleVibes.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: VibesEmptyState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 116),
                sliver: SliverList.separated(
                  itemCount: visibleVibes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final vibe = visibleVibes[index];
                    return VibeCard(
                      vibe: vibe,
                      onProfileTap: () => _showAction('${vibe.authorName} profile will open.'),
                      onLikeTap: () => _feedController.likeVibe(vibe),
                      onCommentTap: () => _openComments(vibe),
                      onShareTap: () => _showAction('Share Vibe will open.'),
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
        label: const Text(
          'Create Vibe',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}
