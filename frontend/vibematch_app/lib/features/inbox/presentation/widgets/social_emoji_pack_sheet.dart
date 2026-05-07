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
        height: 330 + bottomPadding,
        decoration: const BoxDecoration(
          color: Color(0xFFF7F4EF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFECE2D8))),
              ),
              child: Row(
                children: [
                  for (var index = 0; index < _categories.length; index++)
                    Expanded(
                      child: _EmojiCategoryButton(
                        icon: _categories[index].icon,
                        selected: index == _selectedCategoryIndex,
                        onTap: () => setState(() => _selectedCategoryIndex = index),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
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
                    child: Center(
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
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
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF251538) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: selected ? Colors.white : const Color(0xFF7B6A86),
          size: 20,
        ),
      ),
    );
  }
}
