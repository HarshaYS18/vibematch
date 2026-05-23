import 'package:flutter/material.dart';

import '../presentation/story_viewer_page.dart';

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

  static bool isStorySeen(String userId) {
    return userId.hashCode.abs() % 5 == 0;
  }

  @override
  Widget build(BuildContext context) {
    final hasStory = hasActiveStory(userId);
    final seen = isStorySeen(userId);
    final ringSize = size;
    final innerSize = hasStory ? ringSize - 6 : ringSize;

    final avatar = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: ringSize,
      height: ringSize,
      padding: EdgeInsets.all(hasStory ? 2.6 : 0),
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
        width: innerSize,
        height: innerSize,
        padding: EdgeInsets.all(hasStory ? 2.4 : 0),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFFAF7F1),
        ),
        child: ClipOval(child: child),
      ),
    );

    return InkWell(
      onTap: () {
        if (!hasStory) {
          onNoStoryTap?.call();
          return;
        }
        Navigator.of(context).push(
          PageRouteBuilder<void>(
            opaque: true,
            transitionDuration: const Duration(milliseconds: 230),
            reverseTransitionDuration: const Duration(milliseconds: 180),
            pageBuilder: (_, __, ___) => StoryViewerPage(
              userId: userId,
              displayName: displayName,
              avatarText: avatarText,
              avatarUrl: avatarUrl,
              isSeen: seen,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              );
              return FadeTransition(
                opacity: curved,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
                  child: child,
                ),
              );
            },
          ),
        );
      },
      borderRadius: BorderRadius.circular(999),
      child: avatar,
    );
  }
}
