import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/vibes_api_service.dart';
import '../../models/vibe_models.dart';

class VibeReelCommentsSheet extends StatefulWidget {
  const VibeReelCommentsSheet({
    super.key,
    required this.vibe,
    required this.api,
    required this.onCommentAdded,
  });

  final VibeItem vibe;
  final VibesApiService api;
  final VoidCallback onCommentAdded;

  @override
  State<VibeReelCommentsSheet> createState() => _VibeReelCommentsSheetState();
}

class _VibeReelCommentsSheetState extends State<VibeReelCommentsSheet> {
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
        if (index >= 0) {
          _comments[index] = _comments[index].copyWith(likedByMe: result.likedByMe, likesCount: result.likesCount);
        }
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
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.42,
      maxChildSize: 0.94,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 42, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0D5CB), borderRadius: BorderRadius.circular(999))),
            _CommentsHeader(count: _comments.length, loading: _loading, onRefresh: _load),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Text(_error!, style: const TextStyle(color: Color(0xFFE84C72), fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            Expanded(
              child: _comments.isEmpty && !_loading
                  ? const Center(child: Text('No comments yet. Be the first to comment.', style: TextStyle(color: Color(0xFF8C8198), fontWeight: FontWeight.w800)))
                  : ListView.builder(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _comments.length,
                      itemBuilder: (context, index) => _ReelCommentTile(
                        comment: _comments[index],
                        onLike: () => unawaited(_toggleLike(_comments[index])),
                        onReply: () => _reply(_comments[index]),
                      ),
                    ),
            ),
            _ReelCommentComposer(
              controller: _controller,
              focusNode: _focusNode,
              sending: _sending,
              replyingTo: _replyingTo,
              onCancelReply: () => setState(() {
                _replyingTo = null;
                _controller.clear();
              }),
              onSend: () => unawaited(_send()),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentsHeader extends StatelessWidget {
  const _CommentsHeader({required this.count, required this.loading, required this.onRefresh});

  final int count;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 8),
      child: Row(
        children: [
          Expanded(child: Text('Comments  ${_formatCount(count)}', style: const TextStyle(color: Color(0xFF111015), fontSize: 17, fontWeight: FontWeight.w900))),
          if (loading)
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF111015)))
          else
            IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh_rounded, color: Color(0xFF111015), size: 20)),
        ],
      ),
    );
  }
}

class _ReelCommentTile extends StatelessWidget {
  const _ReelCommentTile({required this.comment, required this.onLike, required this.onReply});

  final VibeComment comment;
  final VoidCallback onLike;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = comment.avatarUrl?.trim();
    return Padding(
      padding: EdgeInsets.fromLTRB(comment.isReply ? 54 : 14, 8, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: comment.isReply ? 14 : 17,
            backgroundColor: const Color(0xFF111015),
            backgroundImage: avatarUrl == null || avatarUrl.isEmpty ? null : NetworkImage(avatarUrl),
            child: avatarUrl == null || avatarUrl.isEmpty ? Text(comment.avatarText, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)) : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Color(0xFF111015), fontSize: 13.2, height: 1.32),
                    children: [
                      TextSpan(text: '${comment.name} ', style: const TextStyle(fontWeight: FontWeight.w900)),
                      TextSpan(text: comment.text, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(comment.time, style: const TextStyle(color: Color(0xFF8C8198), fontSize: 10.5, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 14),
                    if (comment.likesCount > 0) ...[
                      Text('${_formatCount(comment.likesCount)} likes', style: const TextStyle(color: Color(0xFF8C8198), fontSize: 10.5, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 14),
                    ],
                    InkWell(onTap: onReply, child: const Text('Reply', style: TextStyle(color: Color(0xFF8C8198), fontSize: 11, fontWeight: FontWeight.w900))),
                  ],
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onLike,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Icon(comment.likedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: comment.likedByMe ? const Color(0xFFE84C72) : const Color(0xFF8C8198), size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReelCommentComposer extends StatelessWidget {
  const _ReelCommentComposer({required this.controller, required this.focusNode, required this.sending, required this.replyingTo, required this.onCancelReply, required this.onSend});

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final VibeComment? replyingTo;
  final VoidCallback onCancelReply;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 10 + MediaQuery.paddingOf(context).bottom),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFECE2D8)))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyingTo != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFF7F3EF), borderRadius: BorderRadius.circular(999)),
              child: Row(
                children: [
                  Expanded(child: Text('Replying to ${replyingTo!.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF8C8198), fontSize: 12, fontWeight: FontWeight.w900))),
                  InkWell(onTap: onCancelReply, customBorder: const CircleBorder(), child: const Icon(Icons.close_rounded, color: Color(0xFF8C8198), size: 17)),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: !sending,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: replyingTo == null ? 'Add a comment...' : 'Add a reply...',
                    filled: true,
                    fillColor: const Color(0xFFF7F3EF),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: sending ? null : onSend,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 43,
                  height: 43,
                  decoration: const BoxDecoration(color: Color(0xFF111015), shape: BoxShape.circle),
                  child: sending ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatCount(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
  return '$value';
}
