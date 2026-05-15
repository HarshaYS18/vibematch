import 'dart:async';

import 'package:flutter/material.dart';

import '../../../social/widgets/friends_invite_sheet.dart';
import '../../data/vibes_api_service.dart';
import '../../models/vibe_models.dart';
import '../widgets/vibe_media_playback_gate.dart';
import '../widgets/vibe_reel_comments_sheet.dart';
import '../widgets/vibe_reel_page.dart';

class MediaVibeDetailPager extends StatefulWidget {
  const MediaVibeDetailPager({
    super.key,
    required this.vibes,
    required this.initialIndex,
  });

  final List<VibeItem> vibes;
  final int initialIndex;

  @override
  State<MediaVibeDetailPager> createState() => _MediaVibeDetailPagerState();
}

class _MediaVibeDetailPagerState extends State<MediaVibeDetailPager> {
  final VibesApiService _api = const VibesApiService();
  late final PageController _pageController;
  late int _activeIndex;
  final Map<String, VibeItem> _stateById = <String, VibeItem>{};

  List<VibeItem> get _vibes => widget.vibes.where((item) => item.mediaType != VibeMediaType.text).toList(growable: false);

  @override
  void initState() {
    super.initState();
    VibeMediaPlaybackGate.feedPlaybackPaused.value = true;
    _activeIndex = widget.initialIndex.clamp(0, _vibes.isEmpty ? 0 : _vibes.length - 1);
    _pageController = PageController(initialPage: _activeIndex);
    for (final vibe in _vibes) {
      _stateById[_key(vibe)] = vibe;
    }
  }

  @override
  void dispose() {
    VibeMediaPlaybackGate.feedPlaybackPaused.value = false;
    _pageController.dispose();
    super.dispose();
  }

  String _key(VibeItem vibe) => vibe.id.trim().isNotEmpty ? vibe.id : '${vibe.authorId}-${vibe.caption.hashCode}';
  VibeItem _stateFor(VibeItem vibe) => _stateById[_key(vibe)] ?? vibe;

  Future<void> _toggleLike(VibeItem vibe) async {
    if (vibe.id.trim().isEmpty) return;
    try {
      final result = await _api.toggleLike(vibe.id);
      if (!mounted) return;
      setState(() {
        final current = _stateFor(vibe);
        _stateById[_key(vibe)] = current.copyWith(likedByMe: result.likedByMe, likes: result.likesCount);
      });
    } catch (error) {
      _toast(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _toggleSave(VibeItem vibe) async {
    if (vibe.id.trim().isEmpty) return;
    try {
      final result = await _api.toggleSave(vibe.id);
      if (!mounted) return;
      setState(() {
        final current = _stateFor(vibe);
        _stateById[_key(vibe)] = current.copyWith(savedByMe: result.savedByMe, saves: result.savesCount);
      });
      _toast(result.savedByMe ? 'Saved Vibe.' : 'Removed from saved Vibes.');
    } catch (error) {
      _toast(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _openShareSheet(VibeItem vibe) async {
    if (vibe.id.trim().isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (_) => FriendsInviteSheet(
        title: 'Share ${vibe.authorName}\'s Vibe',
        actionLabel: 'Send',
        completedLabel: 'Sent',
        sendRoomInvite: false,
        onInvite: (friend) async {
          try {
            final publicUserId = friend.publicUserId ?? int.tryParse(friend.id);
            final result = await _api.shareVibe(vibe.id, targetPublicUserId: publicUserId);
            if (!mounted) return;
            setState(() {
              final current = _stateFor(vibe);
              _stateById[_key(vibe)] = current.copyWith(shares: result.sharesCount);
            });
            _toast('Vibe sent to ${friend.displayName}');
          } catch (error) {
            _toast(error.toString().replaceFirst('Exception: ', ''));
          }
        },
      ),
    );
  }

  Future<void> _openComments(VibeItem vibe) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => VibeReelCommentsSheet(
        vibe: _stateFor(vibe),
        api: _api,
        onCommentAdded: () {
          if (!mounted) return;
          setState(() {
            final current = _stateFor(vibe);
            _stateById[_key(vibe)] = current.copyWith(comments: current.comments + 1);
          });
        },
      ),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)), behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF111015)));
  }

  @override
  Widget build(BuildContext context) {
    if (_vibes.isEmpty) return const Scaffold(backgroundColor: Colors.black, body: SizedBox.shrink());
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _vibes.length,
        onPageChanged: (index) => setState(() => _activeIndex = index),
        itemBuilder: (context, index) {
          final vibe = _stateFor(_vibes[index]);
          return VibeReelPage(
            vibe: vibe,
            onLike: () => unawaited(_toggleLike(vibe)),
            onComments: () => unawaited(_openComments(vibe)),
            onShare: () => unawaited(_openShareSheet(vibe)),
            onSave: () => unawaited(_toggleSave(vibe)),
          );
        },
      ),
    );
  }
}
