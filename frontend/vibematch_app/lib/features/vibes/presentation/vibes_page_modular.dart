import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/vibes_controller.dart';
import '../controllers/vibes_navigation_controller.dart';
import '../models/vibe_models.dart';
import 'sections/vibes_feed_section.dart';
import 'widgets/vibes_feed_tabs.dart';
import 'widgets/vibes_header.dart';
import 'widgets/vibes_status_widgets.dart';

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
    unawaited(_controller.loadFeed());
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

  Future<void> _toggleLike(VibeItem vibe) async {
    try {
      await _controller.toggleLike(vibe);
    } catch (error) {
      if (mounted) VibesNavigationController.showAction(context, error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _toggleSave(VibeItem vibe) async {
    try {
      await _controller.toggleSave(vibe);
      if (mounted) VibesNavigationController.showAction(context, vibe.savedByMe ? 'Removed from saved Vibes.' : 'Saved Vibe.');
    } catch (error) {
      if (mounted) VibesNavigationController.showAction(context, error.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleVibes = _controller.visibleVibes;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF111015),
          onRefresh: _controller.loadFeed,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: VibesHeader(
                  onRefreshTap: () => _controller.loadFeed(),
                  onSettingsTap: () => VibesNavigationController.openSettings(context: context, controller: _controller),
                ),
              ),
              SliverToBoxAdapter(
                child: VibesFeedTabs(
                  selectedTab: _controller.selectedTab,
                  onChanged: _controller.selectTab,
                ),
              ),
              if (_controller.isLoading) const SliverToBoxAdapter(child: VibesLoadingStrip()),
              if (_controller.loadErrorMessage != null)
                SliverToBoxAdapter(
                  child: VibesErrorCard(
                    message: _controller.loadErrorMessage!,
                    onRetry: _controller.loadFeed,
                  ),
                ),
              VibesFeedSection(
                vibes: visibleVibes,
                selectedTab: _controller.selectedTab,
                isLoading: _controller.isLoading,
                hasError: _controller.loadErrorMessage != null,
                onProfileTap: (vibe) => VibesNavigationController.showAction(context, '${vibe.authorName} profile will open.'),
                onLikeTap: _toggleLike,
                onCommentTap: (vibe) => VibesNavigationController.openVibeDetail(context: context, controller: _controller, vibe: vibe),
                onShareTap: (vibe) => VibesNavigationController.openShareSheet(context: context, controller: _controller, vibe: vibe),
                onSaveTap: _toggleSave,
                onMoreTap: (vibe) => VibesNavigationController.openVibeActions(context: context, controller: _controller, vibe: vibe),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 104)),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => VibesNavigationController.openCreateVibe(context: context, controller: _controller),
        backgroundColor: const Color(0xFF111015),
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
    );
  }
}
