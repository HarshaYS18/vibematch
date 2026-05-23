import 'package:flutter/material.dart';

class InboxEmptyState extends StatelessWidget {
  const InboxEmptyState({
    super.key,
    required this.selectedFilter,
    required this.hasSearchQuery,
    this.onClearSearch,
  });

  final String selectedFilter;
  final bool hasSearchQuery;
  final VoidCallback? onClearSearch;

  @override
  Widget build(BuildContext context) {
    final copy = _copyForState();
    return Center(
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 18, 24, 32),
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFEDE7F6)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF251538).withValues(alpha: 0.08),
              blurRadius: 26,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFFFF4D7), Color(0xFFEFFDFB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(copy.icon, color: const Color(0xFF7C3AED), size: 31),
            ),
            const SizedBox(height: 18),
            Text(
              copy.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF251538),
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              copy.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF7B6A86),
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (hasSearchQuery && onClearSearch != null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onClearSearch,
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Clear search'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF251538),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  _EmptyCopy _copyForState() {
    if (hasSearchQuery) {
      return const _EmptyCopy(
        icon: Icons.search_off_rounded,
        title: 'No matches',
        subtitle: 'Try a different name, message, or room invite.',
      );
    }
    switch (selectedFilter) {
      case 'Friends':
        return const _EmptyCopy(
          icon: Icons.favorite_rounded,
          title: 'No friend chats yet',
          subtitle: 'Mutual follows will appear here when you start talking.',
        );
      case 'Stranger Messages':
      case 'Strangers':
        return const _EmptyCopy(
          icon: Icons.shield_rounded,
          title: 'No stranger messages',
          subtitle: 'Requests from non-mutuals will wait here.',
        );
      case 'Unread':
        return const _EmptyCopy(
          icon: Icons.done_all_rounded,
          title: 'Nothing unread',
          subtitle: 'You are caught up across chats, invites, and updates.',
        );
      case 'Calls':
        return const _EmptyCopy(
          icon: Icons.call_rounded,
          title: 'No call activity',
          subtitle: 'Call summaries will stay attached to conversations.',
        );
      default:
        return const _EmptyCopy(
          icon: Icons.forum_rounded,
          title: 'No conversations yet',
          subtitle:
              'Messages, room invites, gift alerts, and team updates will land here.',
        );
    }
  }
}

class _EmptyCopy {
  const _EmptyCopy({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}
