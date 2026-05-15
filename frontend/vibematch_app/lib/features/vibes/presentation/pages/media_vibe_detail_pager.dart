import 'dart:async';

import 'package:flutter/material.dart';

import '../../../social/widgets/friends_invite_sheet.dart';
import '../../data/vibes_api_service.dart';
import '../../models/vibe_models.dart';
import '../widgets/vibe_card_modular.dart';

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
      builder: (_) => _ReelCommentsSheet(vibe: _stateFor(vibe), api: _api, onCommentAdded: () {
        if (!mounted) return;
        setState(() {
          final current = _stateFor(vibe);
          _stateById[_key(vibe)] = current.copyWith(comments: current.comments + 1);
        });
      }),
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
          return _MediaVibeReelPage(
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

class _MediaVibeReelPage extends StatelessWidget {
  const _MediaVibeReelPage({required this.vibe, required this.onLike, required this.onComments, required this.onShare, required this.onSave});

  final VibeItem vibe;
  final VoidCallback onLike;
  final VoidCallback onComments;
  final VoidCallback onShare;
  final VoidCallback onSave;

  String get _caption {
    final caption = vibe.caption.trim();
    final extras = <String>[];
    for (final raw in vibe.mentions) {
      final clean = raw.trim();
      if (clean.isEmpty) continue;
      final token = clean.startsWith('@') ? clean : '@$clean';
      if (!caption.toLowerCase().contains(token.toLowerCase()) && !extras.contains(token)) extras.add(token);
    }
    if (vibe.usesMentionAll && !caption.toLowerCase().contains('@all')) extras.add('@all');
    return extras.isEmpty ? caption : '$caption ${extras.join(' ')}';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(onDoubleTap: onLike, child: VibeMediaPlayer(vibe: vibe, onDoubleTap: onLike, respectFeedPause: false, autoplay: true)),
        const _ReelGradientOverlay(),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: _ReelAuthorCaption(vibe: vibe, caption: _caption)),
                const SizedBox(width: 12),
                _ReelActionRail(vibe: vibe, onLike: onLike, onComments: onComments, onShare: onShare, onSave: onSave),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReelGradientOverlay extends StatelessWidget {
  const _ReelGradientOverlay();

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withValues(alpha: 0.20), Colors.transparent, Colors.black.withValues(alpha: 0.78)],
              stops: const [0, 0.45, 1],
            ),
          ),
        ),
      );
}

class _ReelAuthorCaption extends StatelessWidget {
  const _ReelAuthorCaption({required this.vibe, required this.caption});
  final VibeItem vibe;
  final String caption;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            VibeAvatar(vibe: vibe, size: 38),
            const SizedBox(width: 10),
            Expanded(child: Text(vibe.authorName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900))),
            Text(vibe.timeAgo, style: TextStyle(color: Colors.white.withValues(alpha: 0.76), fontSize: 11, fontWeight: FontWeight.w800)),
          ]),
          if (caption.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(caption, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13.4, height: 1.35, fontWeight: FontWeight.w700)),
          ],
        ],
      );
}

class _ReelActionRail extends StatelessWidget {
  const _ReelActionRail({required this.vibe, required this.onLike, required this.onComments, required this.onShare, required this.onSave});

  final VibeItem vibe;
  final VoidCallback onLike;
  final VoidCallback onComments;
  final VoidCallback onShare;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RailButton(icon: vibe.likedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: vibe.likedByMe ? const Color(0xFFE84C72) : Colors.white, label: _formatCount(vibe.likes), onTap: onLike),
          _RailButton(icon: Icons.mode_comment_rounded, label: _formatCount(vibe.comments), onTap: onComments),
          _RailButton(icon: Icons.send_rounded, label: _formatCount(vibe.shares), onTap: onShare),
          _RailButton(icon: vibe.savedByMe ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, label: _formatCount(vibe.saves), onTap: onSave),
        ],
      );
}

class _RailButton extends StatelessWidget {
  const _RailButton({required this.icon, required this.label, required this.onTap, this.color = Colors.white});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Column(children: [Icon(icon, color: color, size: 31), const SizedBox(height: 4), Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900))]),
        ),
      );
}

class _ReelCommentsSheet extends StatefulWidget {
  const _ReelCommentsSheet({required this.vibe, required this.api, required this.onCommentAdded});
  final VibeItem vibe;
  final VibesApiService api;
  final VoidCallback onCommentAdded;

  @override
  State<_ReelCommentsSheet> createState() => _ReelCommentsSheetState();
}

class _ReelCommentsSheetState extends State<_ReelCommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<VibeComment> _comments = <VibeComment>[];
  VibeComment? _replyingTo;
  bool _loading = false;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading || widget.vibe.id.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final comments = await widget.api.loadComments(widget.vibe.id);
      if (!mounted) return;
      setState(() {
        _comments
          ..clear()
          ..addAll(comments);
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending || widget.vibe.id.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      final parentId = _replyingTo?.parentCommentId ?? _replyingTo?.id;
      final comment = await widget.api.addComment(widget.vibe.id, text, parentCommentId: parentId);
      if (!mounted) return;
      setState(() {
        _comments.add(comment);
        _controller.clear();
        _replyingTo = null;
      });
      widget.onCommentAdded();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleLike(VibeComment comment) async {
    if (widget.vibe.id.trim().isEmpty || comment.id.trim().isEmpty) return;
    try {
      final result = await widget.api.toggleCommentLike(widget.vibe.id, comment.id);
      if (!mounted) return;
      setState(() {
        final index = _comments.indexWhere((item) => item.id == result.commentId);
        if (index >= 0) _comments[index] = _comments[index].copyWith(likedByMe: result.likedByMe, likesCount: result.likesCount);
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _reply(VibeComment comment) {
    setState(() {
      _replyingTo = comment;
      _controller.text = '@${comment.name} ';
      _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.42,
        maxChildSize: 0.94,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(children: [
            const SizedBox(height: 10),
            Container(width: 42, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0D5CB), borderRadius: BorderRadius.circular(999))),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 8, 8),
              child: Row(children: [Expanded(child: Text('Comments  ${_formatCount(_comments.length)}', style: const TextStyle(color: Color(0xFF111015), fontSize: 17, fontWeight: FontWeight.w900))), if (_loading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF111015))) else IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded, color: Color(0xFF111015), size: 20))]),
            ),
            if (_error != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), child: Text(_error!, style: const TextStyle(color: Color(0xFFE84C72), fontSize: 12, fontWeight: FontWeight.w800))),
            Expanded(
              child: _comments.isEmpty && !_loading
                  ? const Center(child: Text('No comments yet. Be the first to comment.', style: TextStyle(color: Color(0xFF8C8198), fontWeight: FontWeight.w800)))
                  : ListView.builder(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _comments.length,
                      itemBuilder: (context, index) => _CommentTile(comment: _comments[index], onLike: () => unawaited(_toggleLike(_comments[index])), onReply: () => _reply(_comments[index])),
                    ),
            ),
            _Composer(controller: _controller, focusNode: _focusNode, sending: _sending, replyingTo: _replyingTo, onCancelReply: () => setState(() { _replyingTo = null; _controller.clear(); }), onSend: () => unawaited(_send())),
          ]),
        ),
      );
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, required this.onLike, required this.onReply});
  final VibeComment comment;
  final VoidCallback onLike;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = comment.avatarUrl?.trim();
    return Padding(
      padding: EdgeInsets.fromLTRB(comment.isReply ? 54 : 14, 8, 8, 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(radius: comment.isReply ? 14 : 17, backgroundColor: const Color(0xFF111015), backgroundImage: avatarUrl == null || avatarUrl.isEmpty ? null : NetworkImage(avatarUrl), child: avatarUrl == null || avatarUrl.isEmpty ? Text(comment.avatarText, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)) : null),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [RichText(text: TextSpan(style: const TextStyle(color: Color(0xFF111015), fontSize: 13.2, height: 1.32), children: [TextSpan(text: '${comment.name} ', style: const TextStyle(fontWeight: FontWeight.w900)), TextSpan(text: comment.text, style: const TextStyle(fontWeight: FontWeight.w600))])), const SizedBox(height: 6), Row(children: [Text(comment.time, style: const TextStyle(color: Color(0xFF8C8198), fontSize: 10.5, fontWeight: FontWeight.w700)), const SizedBox(width: 14), if (comment.likesCount > 0) ...[Text('${_formatCount(comment.likesCount)} likes', style: const TextStyle(color: Color(0xFF8C8198), fontSize: 10.5, fontWeight: FontWeight.w800)), const SizedBox(width: 14)], InkWell(onTap: onReply, child: const Text('Reply', style: TextStyle(color: Color(0xFF8C8198), fontSize: 11, fontWeight: FontWeight.w900)))])])),
        InkWell(onTap: onLike, customBorder: const CircleBorder(), child: Padding(padding: const EdgeInsets.all(9), child: Icon(comment.likedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: comment.likedByMe ? const Color(0xFFE84C72) : const Color(0xFF8C8198), size: 18))),
      ]),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.focusNode, required this.sending, required this.replyingTo, required this.onCancelReply, required this.onSend});
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final VibeComment? replyingTo;
  final VoidCallback onCancelReply;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(12, 8, 12, 10 + MediaQuery.paddingOf(context).bottom),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFECE2D8)))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (replyingTo != null) Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: const Color(0xFFF7F3EF), borderRadius: BorderRadius.circular(999)), child: Row(children: [Expanded(child: Text('Replying to ${replyingTo!.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF8C8198), fontSize: 12, fontWeight: FontWeight.w900))), InkWell(onTap: onCancelReply, customBorder: const CircleBorder(), child: const Icon(Icons.close_rounded, color: Color(0xFF8C8198), size: 17))])),
          Row(children: [Expanded(child: TextField(controller: controller, focusNode: focusNode, enabled: !sending, minLines: 1, maxLines: 3, decoration: InputDecoration(hintText: replyingTo == null ? 'Add a comment...' : 'Add a reply...', filled: true, fillColor: const Color(0xFFF7F3EF), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11), border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none)))), const SizedBox(width: 8), InkWell(onTap: sending ? null : onSend, borderRadius: BorderRadius.circular(999), child: Container(width: 43, height: 43, decoration: const BoxDecoration(color: Color(0xFF111015), shape: BoxShape.circle), child: sending ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 22)))])
        ]),
      );
}

String _formatCount(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
  return '$value';
}
