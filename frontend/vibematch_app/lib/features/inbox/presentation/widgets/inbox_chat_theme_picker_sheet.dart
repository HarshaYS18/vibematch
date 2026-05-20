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
    subtitle: 'Clean soft default',
    colors: [Color(0xFFFAFAFA), Color(0xFFEFF6FF)],
  ),
  InboxChatThemeChoice(
    key: 'royal_dark',
    wallpaperKey: 'royal_dark',
    label: 'Royal Dark',
    subtitle: 'Deep night chat',
    colors: [Color(0xFF111114), Color(0xFF312E81)],
  ),
  InboxChatThemeChoice(
    key: 'rose_sync',
    wallpaperKey: 'rose_sync',
    label: 'Rose Sync',
    subtitle: 'Warm pink glow',
    colors: [Color(0xFFFF4F9A), Color(0xFF7C3AED)],
  ),
  InboxChatThemeChoice(
    key: 'aqua_live',
    wallpaperKey: 'aqua_live',
    label: 'Aqua Live',
    subtitle: 'Fresh blue and teal',
    colors: [Color(0xFF12C7B7), Color(0xFF2563EB)],
  ),
  InboxChatThemeChoice(
    key: 'cricket_green',
    wallpaperKey: 'cricket_green',
    label: 'Cricket Green',
    subtitle: 'Sporty green tone',
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

  static const _ink = Color(0xFF111114);
  static const _muted = Color(0xFF71717A);
  static const _line = Color(0xFFEDEDEF);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: EdgeInsets.fromLTRB(16, 10, 16, 14 + MediaQuery.paddingOf(context).bottom),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 28, offset: const Offset(0, 14))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: const Color(0xFFD4D4D8), borderRadius: BorderRadius.circular(999)))),
            const SizedBox(height: 14),
            const Text('Chat theme', style: TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
            const SizedBox(height: 4),
            const Text('Choose a look for this chat.', style: TextStyle(color: _muted, fontSize: 12.4, height: 1.3, fontWeight: FontWeight.w500)),
            const SizedBox(height: 14),
            ...inboxChatThemeChoices.map((choice) {
              final selected = choice.key == currentThemeKey || choice.wallpaperKey == currentWallpaperKey;
              return _ThemeTile(choice: choice, selected: selected, onTap: () => onSelected(choice));
            }),
          ],
        ),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.choice, required this.selected, required this.onTap});
  final InboxChatThemeChoice choice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF6FF) : const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? const Color(0xFF3797F0) : InboxChatThemePickerSheet._line, width: selected ? 1.3 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(colors: choice.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(choice.label, style: const TextStyle(color: InboxChatThemePickerSheet._ink, fontSize: 13.7, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(choice.subtitle, style: const TextStyle(color: InboxChatThemePickerSheet._muted, fontSize: 11.5, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Icon(selected ? Icons.check_circle_rounded : Icons.chevron_right_rounded, color: selected ? const Color(0xFF3797F0) : InboxChatThemePickerSheet._muted, size: 21),
          ],
        ),
      ),
    );
  }
}
