import 'package:flutter/material.dart';

class SearchDiscoverView extends StatelessWidget {
  const SearchDiscoverView({
    super.key,
    required this.recentSearches,
    required this.topSearches,
    required this.onRecentTap,
    required this.onTopSearchTap,
    required this.onRemoveRecentTap,
    required this.onClearRecentTap,
  });

  final List<String> recentSearches;
  final List<String> topSearches;
  final ValueChanged<String> onRecentTap;
  final ValueChanged<String> onTopSearchTap;
  final ValueChanged<String> onRemoveRecentTap;
  final VoidCallback onClearRecentTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        if (recentSearches.isNotEmpty) ...[
          _SectionTitleRow(
            title: 'Recent searches',
            actionText: 'Clear',
            onActionTap: onClearRecentTap,
          ),
          const SizedBox(height: 8),
          ...recentSearches.map(
            (text) => _RecentSearchTile(
              text: text,
              onTap: () => onRecentTap(text),
              onRemoveTap: () => onRemoveRecentTap(text),
            ),
          ),
          const SizedBox(height: 12),
        ],
        const _SectionTitleRow(title: 'Top searches'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: topSearches.asMap().entries.map((entry) {
            return _TopSearchChip(
              rank: entry.key + 1,
              text: entry.value,
              onTap: () => onTopSearchTap(entry.value),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _SectionTitleRow extends StatelessWidget {
  const _SectionTitleRow({
    required this.title,
    this.actionText,
    this.onActionTap,
  });

  final String title;
  final String? actionText;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF251538),
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (actionText != null)
          InkWell(
            onTap: onActionTap,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Text(
                actionText!,
                style: const TextStyle(
                  color: Color(0xFFE84C72),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RecentSearchTile extends StatelessWidget {
  const _RecentSearchTile({
    required this.text,
    required this.onTap,
    required this.onRemoveTap,
  });

  final String text;
  final VoidCallback onTap;
  final VoidCallback onRemoveTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFECE2D8)),
          ),
          child: Row(
            children: [
              const Icon(Icons.history_rounded, color: Color(0xFF8C8198), size: 19),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF251538),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              InkWell(
                onTap: onRemoveTap,
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(5),
                  child: Icon(Icons.close_rounded, color: Color(0xFF8C8198), size: 17),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopSearchChip extends StatelessWidget {
  const _TopSearchChip({
    required this.rank,
    required this.text,
    required this.onTap,
  });

  final int rank;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hot = rank <= 3;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.fromLTRB(9, 7, 12, 7),
        decoration: BoxDecoration(
          color: hot ? const Color(0xFF251538) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: hot ? const Color(0xFF251538) : const Color(0xFFECE2D8),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: hot
                    ? const Color(0xFFFFC857)
                    : const Color(0xFF12C7B7).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$rank',
                style: TextStyle(
                  color: hot ? const Color(0xFF251538) : const Color(0xFF12C7B7),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              text,
              style: TextStyle(
                color: hot ? Colors.white : const Color(0xFF4A2A63),
                fontSize: 12.3,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
