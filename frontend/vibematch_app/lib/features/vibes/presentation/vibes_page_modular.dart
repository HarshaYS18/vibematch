import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/vibes_controller.dart';
import '../controllers/vibes_navigation_controller.dart';
import '../models/vibe_models.dart';
import 'sections/vibes_feed_section.dart';
import 'widgets/vibe_card_modular.dart';
import 'widgets/vibes_feed_tabs.dart';
import 'widgets/vibes_header.dart';
import 'widgets/vibes_status_widgets.dart';

class VibesPage extends StatefulWidget {
  const VibesPage({super.key, required this.playbackGate});

  final VibeMediaPlaybackGate playbackGate;

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
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.playbackGate.notifyFeedScrolled());
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.playbackGate.notifyFeedScrolled());
    }
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
      final wasSaved = vibe.savedByMe;
      await _controller.toggleSave(vibe);
      if (mounted) VibesNavigationController.showAction(context, wasSaved ? 'Removed from saved Vibes.' : 'Saved Vibe.');
    } catch (error) {
      if (mounted) VibesNavigationController.showAction(context, error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _openSavedOrFeed() async {
    if (_controller.showingSavedVibes) {
      await _controller.loadFeed();
      return;
    }
    await _controller.loadSavedVibes();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification || notification is ScrollEndNotification || notification is UserScrollNotification) {
      widget.playbackGate.notifyFeedScrolled();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final visibleVibes = _controller.visibleVibes;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF111015),
          onRefresh: _controller.showingSavedVibes ? _controller.loadSavedVibes : _controller.loadFeed,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScrollNotification,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(
                  child: ColoredBox(
                    color: Colors.white,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        VibesHeader(
                          showingSaved: _controller.showingSavedVibes,
                          onSavedTap: () => unawaited(_openSavedOrFeed()),
                          onSettingsTap: () => VibesNavigationController.openSettings(context: context, controller: _controller),
                        ),
                        if (!_controller.showingSavedVibes)
                          VibesFeedTabs(
                            selectedTab: _controller.selectedTab,
                            onChanged: _controller.selectTab,
                          ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
                if (_controller.isLoading) const SliverToBoxAdapter(child: VibesLoadingStrip()),
                if (_controller.loadErrorMessage != null)
                  SliverToBoxAdapter(
                    child: VibesErrorCard(
                      message: _controller.loadErrorMessage!,
                      onRetry: _controller.showingSavedVibes ? _controller.loadSavedVibes : _controller.loadFeed,
                    ),
                  ),
                VibesFeedSection(
                  vibes: visibleVibes,
                  selectedTab: _controller.selectedTab,
                  isLoading: _controller.isLoading,
                  hasError: _controller.loadErrorMessage != null,
                  playbackGate: widget.playbackGate,
                  onProfileTap: (vibe) => VibesNavigationController.showAction(context, '${vibe.authorName} profile will open.'),
                  onLikeTap: _toggleLike,
                  onCommentTap: (vibe) => VibesNavigationController.openVibeDetail(context: context, controller: _controller, vibe: vibe, playbackGate: widget.playbackGate),
                  onShareTap: (vibe) => VibesNavigationController.openShareSheet(context: context, controller: _controller, vibe: vibe),
                  onSaveTap: _toggleSave,
                  onMoreTap: (vibe) => VibesNavigationController.openVibeActions(context: context, controller: _controller, vibe: vibe),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 104)),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => VibesNavigationController.openCreateVibe(context: context, controller: _controller, playbackGate: widget.playbackGate),
        backgroundColor: const Color(0xFF111015),
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
    );
  }
}
