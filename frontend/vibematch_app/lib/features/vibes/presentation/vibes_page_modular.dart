import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/vibescontroller.dart';
import '../controllers/vibes_navigationcontroller.dart';
import '../models/vibe_models.dart';
import 'sections/vibes_feed_section.dart';
import 'widgets/vibe_card_modular.dart';
import 'widgets/vibes_feed_tabs.dart';
import 'widgets/vibes_header.dart';
import 'widgets/vibes_status_widgets.dart';

class VibesPage extends ConsumerStatefulWidget {
  const VibesPage({super.key, required this.playbackGate});

  final VibeMediaPlaybackGate playbackGate;

  @override
  ConsumerState<VibesPage> createState() => _VibesPageState();
}

class _VibesPageState extends ConsumerState<VibesPage> {
  @override
  void initState() {
    super.initState();
    unawaited(ref.read(vibesControllerProvider.notifier).loadFeed());
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.playbackGate.notifyFeedScrolled());
  }

  Future<void> _toggleLike(VibeItem vibe) async {
    try {
      await ref.read(vibesControllerProvider.notifier).toggleLike(vibe);
    } catch (error) {
      if (mounted) VibesNavigationController.showAction(context, error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _toggleSave(VibeItem vibe) async {
    try {
      final wasSaved = vibe.savedByMe;
      await ref.read(vibesControllerProvider.notifier).toggleSave(vibe);
      if (mounted) VibesNavigationController.showAction(context, wasSaved ? 'Removed from saved Vibes.' : 'Saved Vibe.');
    } catch (error) {
      if (mounted) VibesNavigationController.showAction(context, error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _openSavedOrFeed() async {
    final state = ref.read(vibesControllerProvider);
    final controller = ref.read(vibesControllerProvider.notifier);
    if (state.showingSavedVibes) {
      await controller.loadFeed();
      return;
    }
    await controller.loadSavedVibes();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification || notification is ScrollEndNotification || notification is UserScrollNotification) {
      widget.playbackGate.notifyFeedScrolled();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final vibes = ref.watch(vibesControllerProvider);
    final controller = ref.read(vibesControllerProvider.notifier);
    ref.listen<VibesState>(vibesControllerProvider, (previous, next) {
      if (previous == next) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.playbackGate.notifyFeedScrolled();
      });
    });
    final visibleVibes = vibes.visibleVibes;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF111015),
          onRefresh: vibes.showingSavedVibes ? controller.loadSavedVibes : controller.loadFeed,
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
                          showingSaved: vibes.showingSavedVibes,
                          onSavedTap: () => unawaited(_openSavedOrFeed()),
                          onSettingsTap: () => VibesNavigationController.openSettings(context: context, controller: controller),
                        ),
                        if (!vibes.showingSavedVibes)
                          VibesFeedTabs(
                            selectedTab: vibes.selectedTab,
                            onChanged: controller.selectTab,
                          ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
                if (vibes.isLoading) const SliverToBoxAdapter(child: VibesLoadingStrip()),
                if (vibes.loadErrorMessage != null)
                  SliverToBoxAdapter(
                    child: VibesErrorCard(
                      message: vibes.loadErrorMessage!,
                      onRetry: vibes.showingSavedVibes ? controller.loadSavedVibes : controller.loadFeed,
                    ),
                  ),
                VibesFeedSection(
                  vibes: visibleVibes,
                  selectedTab: vibes.selectedTab,
                  isLoading: vibes.isLoading,
                  hasError: vibes.loadErrorMessage != null,
                  playbackGate: widget.playbackGate,
                  onProfileTap: (vibe) => VibesNavigationController.showAction(context, '${vibe.authorName} profile will open.'),
                  onLikeTap: _toggleLike,
                  onCommentTap: (vibe) => VibesNavigationController.openVibeDetail(context: context, controller: controller, vibe: vibe, playbackGate: widget.playbackGate),
                  onShareTap: (vibe) => VibesNavigationController.openShareSheet(context: context, controller: controller, vibe: vibe),
                  onSaveTap: _toggleSave,
                  onMoreTap: (vibe) => VibesNavigationController.openVibeActions(context: context, controller: controller, vibe: vibe),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 104)),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => VibesNavigationController.openCreateVibe(context: context, controller: controller, playbackGate: widget.playbackGate),
        backgroundColor: const Color(0xFF111015),
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
    );
  }
}
