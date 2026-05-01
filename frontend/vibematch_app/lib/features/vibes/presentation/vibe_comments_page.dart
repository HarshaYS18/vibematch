import 'package:flutter/material.dart';

import '../data/vibes_mock_data.dart';
import '../models/vibe_comment.dart';
import '../models/vibe_item.dart';
import 'widgets/vibes_ui_helpers.dart';

class VibeCommentsPage extends StatefulWidget {
  const VibeCommentsPage({
    super.key,
    required this.vibe,
  });

  final VibeItem vibe;

  @override
  State<VibeCommentsPage> createState() => _VibeCommentsPageState();
}

class _VibeCommentsPageState extends State<VibeCommentsPage> {
  final TextEditingController _commentController = TextEditingController();
  final List<VibeComment> _comments = List<VibeComment>.from(VibesMockData.comments);

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
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

  void _sendComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _comments.insert(
        0,
        VibeComment(
          name: 'Founder',
          avatarText: 'F',
          text: text,
          time: 'Just now',
        ),
      );
      _commentController.clear();
    });

    final hasAll = RegExp(r'(^|\s)@all\b', caseSensitive: false).hasMatch(text);
    final mentions = RegExp(r'(^|\s)@(?!all\b)([a-zA-Z0-9_]{2,24})')
        .allMatches(text)
        .map((match) => match.group(2))
        .whereType<String>()
        .toList();

    if (hasAll) {
      _showAction('All followers will be notified later.');
    } else if (mentions.isNotEmpty) {
      _showAction('Mention notification will be sent to ${mentions.join(', ')} later.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFECE2D8)),
                ),
              ),
              child: Row(
                children: [
                  VibesRoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Comments · ${widget.vibe.authorName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF251538),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                itemCount: _comments.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _CommentCard(comment: _comments[index]);
                },
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                14,
                10,
                14,
                MediaQuery.paddingOf(context).bottom + 12,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFECE2D8))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendComment(),
                      decoration: InputDecoration(
                        hintText: 'Comment with @name or @all...',
                        hintStyle: const TextStyle(
                          color: Color(0xFF8C8198),
                          fontWeight: FontWeight.w600,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFFAF7F1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: Color(0xFFECE2D8)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: Color(0xFFECE2D8)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: Color(0xFF12C7B7)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: _sendComment,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF251538),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.comment});

  final VibeComment comment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: vibePanelDecoration(radius: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VibesAvatarBubble(
            text: comment.avatarText,
            colors: const [Color(0xFF12C7B7), Color(0xFF6D5DF6)],
            size: 42,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF251538),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      comment.time,
                      style: const TextStyle(
                        color: Color(0xFF8C8198),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  comment.text,
                  style: const TextStyle(
                    color: Color(0xFF5E526B),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
