import 'package:flutter/material.dart';

class StoryAvatarRing extends StatelessWidget {
  const StoryAvatarRing({
    super.key,
    required this.userId,
    required this.displayName,
    required this.avatarText,
    required this.child,
    this.avatarUrl,
    this.size = 58,
    this.onNoStoryTap,
  });

  final String userId;
  final String displayName;
  final String avatarText;
  final String? avatarUrl;
  final Widget child;
  final double size;
  final VoidCallback? onNoStoryTap;

  static bool hasActiveStory(String userId) {
    if (userId.trim().isEmpty || userId.startsWith('__')) return false;
    return userId.hashCode.abs() % 3 != 0;
  }

  static bool isStorySeen(String userId) => userId.hashCode.abs() % 5 == 0;

  @override
  Widget build(BuildContext context) {
    final hasStory = hasActiveStory(userId);
    final seen = isStorySeen(userId);
    final avatar = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: size,
      height: size,
      padding: EdgeInsets.all(hasStory ? 2.7 : 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasStory
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: seen
                    ? const [Color(0xFFC9C1D0), Color(0xFF9B91A3)]
                    : const [Color(0xFF12C7B7), Color(0xFF7C3AED), Color(0xFFE84C72)],
              )
            : null,
      ),
      child: Container(
        padding: EdgeInsets.all(hasStory ? 2.4 : 0),
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFAF7F1)),
        child: ClipOval(child: child),
      ),
    );

    return InkWell(
      onTap: () {
        if (!hasStory) {
          onNoStoryTap?.call();
          return;
        }
        showGeneralDialog<void>(
          context: context,
          barrierDismissible: true,
          barrierLabel: 'Story',
          barrierColor: Colors.black,
          transitionDuration: const Duration(milliseconds: 220),
          pageBuilder: (context, animation, secondaryAnimation) => _InlineStoryViewer(
            displayName: displayName,
            avatarText: avatarText,
            avatarUrl: avatarUrl,
          ),
          transitionBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
            return FadeTransition(opacity: curved, child: ScaleTransition(scale: Tween<double>(begin: 0.96, end: 1).animate(curved), child: child));
          },
        );
      },
      borderRadius: BorderRadius.circular(999),
      child: avatar,
    );
  }
}

class _InlineStoryViewer extends StatefulWidget {
  const _InlineStoryViewer({required this.displayName, required this.avatarText, this.avatarUrl});

  final String displayName;
  final String avatarText;
  final String? avatarUrl;

  @override
  State<_InlineStoryViewer> createState() => _InlineStoryViewerState();
}

class _InlineStoryViewerState extends State<_InlineStoryViewer> {
  int _frame = 0;

  static const _gradients = <List<Color>>[
    [Color(0xFF160C24), Color(0xFF7C3AED), Color(0xFFE84C72)],
    [Color(0xFF071F22), Color(0xFF12C7B7), Color(0xFF251538)],
  ];

  void _next() {
    if (_frame >= _gradients.length - 1) {
      Navigator.maybePop(context);
    } else {
      setState(() => _frame += 1);
    }
  }

  void _previous() {
    if (_frame <= 0) return;
    setState(() => _frame -= 1);
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = widget.avatarUrl?.trim();
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: _gradients[_frame])),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 58),
                      const SizedBox(height: 14),
                      Text(widget.displayName, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _previous)),
                  Expanded(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _next)),
                ],
              ),
            ),
            Positioned(
              top: 8,
              left: 10,
              right: 10,
              child: Column(
                children: [
                  Row(
                    children: List.generate(_gradients.length, (index) {
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          height: 3,
                          decoration: BoxDecoration(color: index <= _frame ? Colors.white : Colors.white24, borderRadius: BorderRadius.circular(99)),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF251538),
                        backgroundImage: avatarUrl == null || avatarUrl.isEmpty ? null : NetworkImage(avatarUrl),
                        child: avatarUrl == null || avatarUrl.isEmpty ? Text(widget.avatarText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)) : null,
                      ),
                      const SizedBox(width: 9),
                      Expanded(child: Text(widget.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900))),
                      IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.close_rounded, color: Colors.white)),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 18,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white24)),
                child: const Text('Reply', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
