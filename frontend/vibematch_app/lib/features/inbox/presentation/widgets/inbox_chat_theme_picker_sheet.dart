import 'package:flutter/material.dart';

class InboxChatThemeChoice {
  const InboxChatThemeChoice({
    required this.key,
    required this.wallpaperKey,
    required this.label,
    required this.subtitle,
    required this.colors,
    this.wallpaperUrl,
  });

  final String key;
  final String wallpaperKey;
  final String label;
  final String subtitle;
  final List<Color> colors;
  final String? wallpaperUrl;
}

const List<InboxChatThemeChoice> inboxChatThemeChoices = <InboxChatThemeChoice>[
  InboxChatThemeChoice(
    key: 'pearl',
    wallpaperKey: 'premium_pearl',
    label: 'Pearl Glow',
    subtitle: 'Soft premium default',
    colors: [Color(0xFFF8F5FF), Color(0xFFFFF7F2)],
  ),
  InboxChatThemeChoice(
    key: 'royal_dark',
    wallpaperKey: 'royal_dark',
    label: 'Royal Dark',
    subtitle: 'Luxury night chat',
    colors: [Color(0xFF12091F), Color(0xFF3B1666)],
  ),
  InboxChatThemeChoice(
    key: 'rose_sync',
    wallpaperKey: 'rose_sync',
    label: 'Rose Sync',
    subtitle: 'Romantic neon vibe',
    colors: [Color(0xFFFF4F9A), Color(0xFF7C3AED)],
  ),
  InboxChatThemeChoice(
    key: 'aqua_live',
    wallpaperKey: 'aqua_live',
    label: 'Aqua Live',
    subtitle: 'Fresh blue/teal room feel',
    colors: [Color(0xFF12C7B7), Color(0xFF2563EB)],
  ),
  InboxChatThemeChoice(
    key: 'cricket_green',
    wallpaperKey: 'cricket_green',
    label: 'Cricket Green',
    subtitle: 'Sport mode inspired',
    colors: [Color(0xFF166534), Color(0xFF84CC16)],
  ),
];

class InboxChatThemePickerSheet extends StatelessWidget {
  const InboxChatThemePickerSheet({
    super.key,
    required this.currentThemeKey,
    required this.currentWallpaperKey,
    required this.onSelected,
  });

  final String? currentThemeKey;
  final String? currentWallpaperKey;
  final ValueChanged<InboxChatThemeChoice> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(14),
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0D5CB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Chat theme',
              style: TextStyle(
                color: Color(0xFF251538),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Set the mood for this chat with a synced wallpaper and bubble backdrop.',
              style: TextStyle(
                color: Color(0xFF7B6A86),
                fontSize: 12.2,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...inboxChatThemeChoices.map((choice) {
              final selected =
                  choice.key == currentThemeKey ||
                  choice.wallpaperKey == currentWallpaperKey;
              return _ThemeTile(
                choice: choice,
                selected: selected,
                onTap: () => onSelected(choice),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.choice,
    required this.selected,
    required this.onTap,
  });
  final InboxChatThemeChoice choice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF8F5FF) : const Color(0xFFFAF7F1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFF7C3AED) : const Color(0xFFECE2D8),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: choice.colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    choice.label,
                    style: const TextStyle(
                      color: Color(0xFF251538),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    choice.subtitle,
                    style: const TextStyle(
                      color: Color(0xFF7B6A86),
                      fontSize: 11.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.chevron_right_rounded,
              color: selected
                  ? const Color(0xFF12C7B7)
                  : const Color(0xFF9B8CA5),
            ),
          ],
        ),
      ),
    );
  }
}
