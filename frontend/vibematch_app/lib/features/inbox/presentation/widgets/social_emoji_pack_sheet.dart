import 'package:flutter/material.dart';

class SocialEmojiPackSheet extends StatefulWidget {
  const SocialEmojiPackSheet({
    super.key,
    required this.onEmojiSelected,
  });

  final ValueChanged<String> onEmojiSelected;

  @override
  State<SocialEmojiPackSheet> createState() => _SocialEmojiPackSheetState();
}

class _SocialEmojiPackSheetState extends State<SocialEmojiPackSheet> {
  static const _ink = Color(0xFF111114);
  static const _muted = Color(0xFF71717A);
  static const _line = Color(0xFFEDEDEF);
  static const _blue = Color(0xFF3797F0);

  int _selectedCategoryIndex = 0;

  static const List<_EmojiCategory> _categories = [
    _EmojiCategory(
      icon: Icons.emoji_emotions_rounded,
      emojis: [
        '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣',
        '🙂', '🙃', '😉', '😊', '😇', '🥰', '😍', '🤩',
        '😘', '😗', '😚', '😙', '🥲', '😋', '😛', '😜',
        '🤪', '😝', '🤑', '🤗', '🤭', '🫢', '🫣', '🤫',
        '🤔', '🫡', '🤐', '🤨', '😐', '😑', '😶', '🫥',
        '😏', '😒', '🙄', '😬', '😮‍💨', '🤥', '😌', '😔',
        '😪', '🤤', '😴', '😷', '🤒', '🤕', '🤢', '🤮',
        '🤧', '🥵', '🥶', '🥴', '😵', '🤯', '🤠', '🥳',
        '🥸', '😎', '🤓', '🧐', '😕', '🫤', '😟', '🙁',
        '☹️', '😮', '😯', '😲', '😳', '🥺', '🥹', '😦',
        '😧', '😨', '😰', '😥', '😢', '😭', '😱', '😖',
        '😣', '😞', '😓', '😩', '😫', '🥱', '😤', '😡',
        '😠', '🤬', '😈', '👿', '💀', '☠️', '💩', '🤡',
      ],
    ),
    _EmojiCategory(
      icon: Icons.favorite_rounded,
      emojis: [
        '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍',
        '🤎', '💔', '❤️‍🔥', '❤️‍🩹', '💕', '💞', '💓', '💗',
        '💖', '💘', '💝', '💟', '♥️', '💋', '💌', '💤',
        '💢', '💥', '💫', '💦', '💨', '🕳️', '💣', '💬',
        '👁️‍🗨️', '🗨️', '🗯️', '💭', '💯', '🔅', '🔆', '✨',
        '⚡', '🔥', '🌈', '☀️', '🌙', '⭐', '🌟', '🌠',
      ],
    ),
    _EmojiCategory(
      icon: Icons.back_hand_rounded,
      emojis: [
        '👋', '🤚', '🖐️', '✋', '🖖', '👌', '🤌', '🤏',
        '✌️', '🤞', '🫰', '🤟', '🤘', '🤙', '👈', '👉',
        '👆', '🖕', '👇', '☝️', '🫵', '👍', '👎', '✊',
        '👊', '🤛', '🤜', '👏', '🙌', '🫶', '👐', '🤲',
        '🤝', '🙏', '✍️', '💅', '🤳', '💪', '🦾', '🦿',
      ],
    ),
    _EmojiCategory(
      icon: Icons.pets_rounded,
      emojis: [
        '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼',
        '🐻‍❄️', '🐨', '🐯', '🦁', '🐮', '🐷', '🐸', '🐵',
        '🙈', '🙉', '🙊', '🐒', '🐔', '🐧', '🐦', '🐤',
        '🦆', '🦅', '🦉', '🦇', '🐺', '🐗', '🐴', '🦄',
        '🐝', '🪲', '🐞', '🦋', '🐌', '🐢', '🐍', '🦎',
        '🐙', '🦑', '🦐', '🦞', '🦀', '🐡', '🐠', '🐬',
      ],
    ),
    _EmojiCategory(
      icon: Icons.fastfood_rounded,
      emojis: [
        '🍏', '🍎', '🍐', '🍊', '🍋', '🍌', '🍉', '🍇',
        '🍓', '🫐', '🍈', '🍒', '🍑', '🥭', '🍍', '🥥',
        '🥝', '🍅', '🥑', '🥦', '🥬', '🥒', '🌶️', '🫑',
        '🌽', '🥕', '🫒', '🧄', '🧅', '🥔', '🍠', '🥐',
        '🥯', '🍞', '🥖', '🧀', '🥚', '🍳', '🥞', '🧇',
        '🍗', '🍖', '🍔', '🍟', '🍕', '🌭', '🥪', '🌮',
        '🌯', '🥙', '🧆', '🍝', '🍜', '🍲', '🍛', '🍣',
        '🍱', '🥟', '🍤', '🍙', '🍚', '🍘', '🍥', '🥠',
        '🥮', '🍢', '🍡', '🍧', '🍨', '🍦', '🥧', '🧁',
        '🍰', '🎂', '🍮', '🍭', '🍬', '🍫', '🍿', '🍩',
      ],
    ),
    _EmojiCategory(
      icon: Icons.sports_esports_rounded,
      emojis: [
        '⚽', '🏀', '🏈', '⚾', '🥎', '🎾', '🏐', '🏉',
        '🥏', '🎱', '🪀', '🏓', '🏸', '🏒', '🏑', '🥍',
        '🏏', '🪃', '🥅', '⛳', '🪁', '🏹', '🎣', '🤿',
        '🥊', '🥋', '🎽', '🛹', '🛼', '🛷', '⛸️', '🥌',
        '🎿', '⛷️', '🏂', '🪂', '🏋️', '🤼', '🤸', '⛹️',
        '🤺', '🤾', '🏌️', '🏇', '🧘', '🏄', '🏊', '🚴',
        '🎮', '🕹️', '🎲', '♟️', '🎯', '🎳', '🎭', '🎨',
      ],
    ),
    _EmojiCategory(
      icon: Icons.directions_car_rounded,
      emojis: [
        '🚗', '🚕', '🚙', '🚌', '🚎', '🏎️', '🚓', '🚑',
        '🚒', '🚐', '🛻', '🚚', '🚛', '🚜', '🦯', '🦽',
        '🦼', '🛴', '🚲', '🛵', '🏍️', '🛺', '🚨', '🚔',
        '🚍', '🚘', '🚖', '🚡', '🚠', '🚟', '🚃', '🚋',
        '🚞', '🚝', '🚄', '🚅', '🚈', '🚂', '✈️', '🛫',
        '🛬', '🛩️', '💺', '🚀', '🛸', '🚁', '🛶', '⛵',
        '🚤', '🛥️', '🛳️', '⛴️', '🚢', '⚓', '🛟', '⛽',
      ],
    ),
    _EmojiCategory(
      icon: Icons.flag_rounded,
      emojis: [
        '🏳️', '🏴', '🏁', '🚩', '🏳️‍🌈', '🏳️‍⚧️', '🇮🇳', '🇺🇸',
        '🇬🇧', '🇦🇪', '🇸🇦', '🇶🇦', '🇰🇼', '🇴🇲', '🇧🇭', '🇸🇬',
        '🇲🇾', '🇮🇩', '🇵🇭', '🇹🇭', '🇯🇵', '🇰🇷', '🇨🇳', '🇦🇺',
        '🇨🇦', '🇧🇷', '🇫🇷', '🇩🇪', '🇮🇹', '🇪🇸', '🇳🇱', '🇵🇹',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedCategory = _categories[_selectedCategoryIndex];
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      top: false,
      child: Container(
        height: 338 + bottomPadding,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 28, offset: const Offset(0, 14))],
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 38, height: 4, decoration: BoxDecoration(color: const Color(0xFFD4D4D8), borderRadius: BorderRadius.circular(999))),
            const SizedBox(height: 10),
            SizedBox(
              height: 42,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return _EmojiCategoryButton(
                    icon: _categories[index].icon,
                    selected: index == _selectedCategoryIndex,
                    onTap: () => setState(() => _selectedCategoryIndex = index),
                  );
                },
              ),
            ),
            const Divider(height: 1, color: _line),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                physics: const BouncingScrollPhysics(),
                itemCount: selectedCategory.emojis.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemBuilder: (context, index) {
                  final emoji = selectedCategory.emojis[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => widget.onEmojiSelected(emoji),
                    child: Center(child: Text(emoji, style: const TextStyle(fontSize: 25))),
                  );
                },
              ),
            ),
            SizedBox(height: bottomPadding),
          ],
        ),
      ),
    );
  }
}

class _EmojiCategory {
  const _EmojiCategory({required this.icon, required this.emojis});

  final IconData icon;
  final List<String> emojis;
}

class _EmojiCategoryButton extends StatelessWidget {
  const _EmojiCategoryButton({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: selected ? _SocialEmojiPackSheetState._ink : const Color(0xFFF4F4F5),
          shape: BoxShape.circle,
          border: Border.all(color: selected ? _SocialEmojiPackSheetState._ink : _SocialEmojiPackSheetState._line),
        ),
        child: Icon(icon, color: selected ? Colors.white : _SocialEmojiPackSheetState._muted, size: 20),
      ),
    );
  }
}
