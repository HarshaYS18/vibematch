import 'package:flutter/material.dart';

import '../../data/vibes_mock_data.dart';
import '../../models/vibe_models.dart';

class VibeCommentsPageModular extends StatefulWidget {
  const VibeCommentsPageModular({
    super.key,
    required this.vibe,
    required this.onCommentAdded,
  });

  final VibeItem vibe;
  final VoidCallback onCommentAdded;

  @override
  State<VibeCommentsPageModular> createState() => _VibeCommentsPageModularState();
}

class _VibeCommentsPageModularState extends State<VibeCommentsPageModular> {
  final TextEditingController _commentController = TextEditingController();
  final List<VibeComment> _comments = [...VibesMockData.comments];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
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
    widget.onCommentAdded();
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
                border: Border(bottom: BorderSide(color: Color(0xFFECE2D8))),
              ),
              child: Row(
                children: [
                  _RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Comments',
                      style: TextStyle(
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
                itemBuilder: (context, index) => _CommentCard(comment: _comments[index]),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFECE2D8))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFF8C5CF6),
          child: Text(comment.avatarText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFECE2D8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(comment.name, style: const TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(comment.text, style: const TextStyle(color: Color(0xFF5E526B), height: 1.3, fontWeight: FontWeight.w600)),
                const SizedBox(height: 5),
                Text(comment.time, style: const TextStyle(color: Color(0xFF8C8198), fontSize: 10.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ],
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
        ),
        child: Icon(icon, color: const Color(0xFF251538)),
      ),
    );
  }
}
