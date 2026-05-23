import 'package:flutter/material.dart';

import '../../data/inbox_stories_api_service.dart';
import '../../models/inbox_models.dart';

class InboxActiveUsersStrip extends StatelessWidget {
  const InboxActiveUsersStrip({
    super.key,
    required this.conversations,
    required this.stories,
    required this.storiesLoading,
    required this.onCreateStory,
    required this.onStoryTap,
    required this.onConversationTap,
  });

  final List<InboxConversation> conversations;
  final List<InboxStoryItem> stories;
  final bool storiesLoading;
  final VoidCallback onCreateStory;
  final ValueChanged<InboxStoryItem> onStoryTap;
  final ValueChanged<InboxConversation> onConversationTap;

  @override
  Widget build(BuildContext context) {
    final activeFriends = conversations
        .where(
          (conversation) =>
              !conversation.isStrangerHub &&
              !conversation.isStranger &&
              (conversation.isOnline ||
                  conversation.isMutualFollowChat ||
                  conversation.isOfficial),
        )
        .take(10)
        .toList();
    final itemCount = 1 + stories.length + activeFriends.length;

    return SizedBox(
      height: 108,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: storiesLoading && itemCount == 1 ? 4 : itemCount,
        separatorBuilder: (context, index) => const SizedBox(width: 13),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _StoryOrActiveBubble.create(onTap: onCreateStory);
          }
          if (storiesLoading && itemCount == 1) {
            return const _ActiveSkeleton();
          }
          final storyIndex = index - 1;
          if (storyIndex < stories.length) {
            final story = stories[storyIndex];
            return _StoryOrActiveBubble.story(
              story: story,
              onTap: () => onStoryTap(story),
            );
          }
          final conversation = activeFriends[storyIndex - stories.length];
          return _StoryOrActiveBubble.conversation(
            conversation: conversation,
            onTap: () => onConversationTap(conversation),
          );
        },
      ),
    );
  }
}

class _StoryOrActiveBubble extends StatelessWidget {
  const _StoryOrActiveBubble({
    required this.label,
    required this.avatarText,
    required this.colors,
    required this.onTap,
    this.imageUrl,
    this.icon,
    this.online = false,
    this.dimmed = false,
  });

  factory _StoryOrActiveBubble.create({required VoidCallback onTap}) {
    return _StoryOrActiveBubble(
      label: 'Your story',
      avatarText: '+',
      colors: const [Color(0xFF12C7B7), Color(0xFF7C3AED)],
      icon: Icons.add_rounded,
      onTap: onTap,
    );
  }

  factory _StoryOrActiveBubble.story({
    required InboxStoryItem story,
    required VoidCallback onTap,
  }) {
    return _StoryOrActiveBubble(
      label: story.ownerName.isEmpty ? 'Story' : story.ownerName,
      avatarText: _initials(story.ownerName),
      imageUrl: story.ownerAvatarUrl,
      colors: story.isViewed
          ? const [Color(0xFFB8B1C1), Color(0xFFD8D2DD)]
          : const [Color(0xFFFF4F9A), Color(0xFFFFB020), Color(0xFF7C3AED)],
      onTap: onTap,
      dimmed: story.isViewed,
    );
  }

  factory _StoryOrActiveBubble.conversation({
    required InboxConversation conversation,
    required VoidCallback onTap,
  }) {
    return _StoryOrActiveBubble(
      label: conversation.title,
      avatarText: conversation.avatarText,
      imageUrl: conversation.avatarUrl,
      colors: conversation.colors,
      onTap: onTap,
      online: conversation.isOnline,
      dimmed: !conversation.isOnline,
    );
  }

  final String label;
  final String avatarText;
  final String? imageUrl;
  final List<Color> colors;
  final IconData? icon;
  final VoidCallback onTap;
  final bool online;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final ringColors = colors.length > 1
        ? colors
        : const [Color(0xFF12C7B7), Color(0xFF7C3AED)];
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: dimmed ? 0.76 : 1,
                  child: Container(
                    width: 62,
                    height: 62,
                    padding: const EdgeInsets.all(2.4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: ringColors),
                      boxShadow: [
                        BoxShadow(
                          color: ringColors.last.withValues(alpha: 0.18),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(2.2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: _AvatarFace(
                          text: avatarText,
                          imageUrl: imageUrl,
                          icon: icon,
                          colors: ringColors,
                        ),
                      ),
                    ),
                  ),
                ),
                if (online)
                  Positioned(
                    right: 2,
                    bottom: 3,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF18D17B),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF5E4B6F),
                fontSize: 10.7,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _initials(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'S';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }
}

class _AvatarFace extends StatelessWidget {
  const _AvatarFace({
    required this.text,
    required this.imageUrl,
    required this.icon,
    required this.colors,
  });

  final String text;
  final String? imageUrl;
  final IconData? icon;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) =>
            _AvatarInitial(text: text, icon: icon, colors: colors),
      );
    }
    return _AvatarInitial(text: text, icon: icon, colors: colors);
  }
}

class _AvatarInitial extends StatelessWidget {
  const _AvatarInitial({
    required this.text,
    required this.icon,
    required this.colors,
  });

  final String text;
  final IconData? icon;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: LinearGradient(colors: colors)),
      child: Center(
        child: icon == null
            ? Text(
                text.trim().isEmpty ? 'V' : text.trim().characters.first,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              )
            : Icon(icon, color: Colors.white, size: 25),
      ),
    );
  }
}

class _ActiveSkeleton extends StatelessWidget {
  const _ActiveSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.62),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 44,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.66),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}
