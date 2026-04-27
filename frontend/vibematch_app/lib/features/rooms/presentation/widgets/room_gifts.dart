import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'room_theme.dart';

class GiftPanel extends StatelessWidget {
  const GiftPanel({
    super.key,
    required this.gifts,
    required this.users,
    required this.selectedCategory,
    required this.selectedGift,
    required this.selectedReceiverIds,
    required this.selectedCombo,
    required this.coinBalance,
    required this.onCategoryChanged,
    required this.onGiftSelected,
    required this.onReceiverToggle,
    required this.onComboChanged,
    required this.onSend,
    required this.onRecharge,
  });

  final List<GiftItem> gifts;
  final List<SeatUser> users;
  final GiftCategory selectedCategory;
  final GiftItem? selectedGift;
  final Set<String> selectedReceiverIds;
  final int selectedCombo;
  final int coinBalance;
  final ValueChanged<GiftCategory> onCategoryChanged;
  final ValueChanged<GiftItem> onGiftSelected;
  final ValueChanged<String> onReceiverToggle;
  final ValueChanged<int> onComboChanged;
  final VoidCallback onSend;
  final VoidCallback onRecharge;

  static const List<int> combos = [1, 9, 69, 99, 999];

  @override
  Widget build(BuildContext context) {
    final filtered = gifts.where((gift) => gift.category == selectedCategory).toList();
    final allSelected = users.isNotEmpty && selectedReceiverIds.length == users.length;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.30,
      child: Container(
        padding: EdgeInsets.fromLTRB(10, 7, 10, MediaQuery.paddingOf(context).bottom + 8),
        decoration: const BoxDecoration(
          color: Color(0xFF12101D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(width: 42),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.card_giftcard_rounded, color: RoomColors.gold, size: 18),
                const SizedBox(width: 6),
                const Text('Gifts', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                const SizedBox(width: 8),
                Expanded(child: _CategoryStrip(selectedCategory: selectedCategory, onChanged: onCategoryChanged)),
                _TinyIconButton(icon: Icons.apps_rounded, onTap: () => RoomToast.show(context, 'Bag / inventory opened')),
              ],
            ),
            const SizedBox(height: 7),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: users.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 7),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _ReceiverAvatar(
                      selected: allSelected,
                      label: 'All',
                      colors: const [RoomColors.gold, RoomColors.coral],
                      onTap: () => onReceiverToggle('__all__'),
                    );
                  }
                  final user = users[index - 1];
                  return _ReceiverAvatar(
                    selected: selectedReceiverIds.contains(user.id),
                    label: avatarLetter(user.name),
                    colors: user.avatarColors,
                    onTap: () => onReceiverToggle(user.id),
                  );
                },
              ),
            ),
            const SizedBox(height: 7),
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final gift = filtered[index];
                  return CompactGiftCard(
                    gift: gift,
                    selected: selectedGift?.id == gift.id,
                    onTap: () => onGiftSelected(gift),
                  );
                },
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                GestureDetector(
                  onTap: onSend,
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: const LinearGradient(colors: [RoomColors.gold, RoomColors.coral]),
                    ),
                    child: const Center(child: Text('Send', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900))),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: selectedCombo,
                      dropdownColor: const Color(0xFF201A2C),
                      iconEnabledColor: Colors.white,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
                      items: combos.map((combo) => DropdownMenuItem(value: combo, child: Text('x$combo'))).toList(),
                      onChanged: (value) {
                        if (value != null) onComboChanged(value);
                      },
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onRecharge,
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.add_circle_rounded, color: RoomColors.aqua, size: 17),
                        const SizedBox(width: 5),
                        const Icon(Icons.toll_rounded, color: RoomColors.gold, size: 15),
                        const SizedBox(width: 4),
                        Text('$coinBalance', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({required this.selectedCategory, required this.onChanged});

  final GiftCategory selectedCategory;
  final ValueChanged<GiftCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: GiftCategory.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 5),
        itemBuilder: (context, index) {
          final category = GiftCategory.values[index];
          final selected = category == selectedCategory;
          return GestureDetector(
            onTap: () => onChanged(category),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? RoomColors.gold : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                category.label,
                style: TextStyle(color: selected ? RoomColors.deep : Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReceiverAvatar extends StatelessWidget {
  const _ReceiverAvatar({required this.selected, required this.label, required this.colors, required this.onTap});

  final bool selected;
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: selected ? RoomColors.gold : Colors.white24, width: selected ? 2 : 1),
        ),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: colors)),
          child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }
}

class CompactGiftCard extends StatelessWidget {
  const CompactGiftCard({super.key, required this.gift, required this.selected, required this.onTap});

  final GiftItem gift;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 76,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: selected ? 0.13 : 0.07),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: selected ? gift.colors.first : Colors.white12, width: selected ? 1.4 : 1),
        ),
        child: Column(
          children: [
            GradientIconBox(icon: gift.icon, colors: gift.colors, size: 34),
            const SizedBox(height: 5),
            Text(gift.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900)),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.toll_rounded, color: RoomColors.gold, size: 11),
                const SizedBox(width: 2),
                Text('${gift.coins}', style: const TextStyle(color: RoomColors.gold, fontSize: 10, fontWeight: FontWeight.w900)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class GiftSlideStack extends StatelessWidget {
  const GiftSlideStack({
    super.key,
    required this.slides,
    required this.onComboTap,
  });

  final List<GiftSlide> slides;
  final ValueChanged<GiftSlide> onComboTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: slides.take(2).map((slide) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: GiftSlideCard(
            slide: slide,
            onComboTap: () => onComboTap(slide),
          ),
        );
      }).toList(),
    );
  }
}

class GiftSlideCard extends StatelessWidget {
  const GiftSlideCard({
    super.key,
    required this.slide,
    required this.onComboTap,
  });

  final GiftSlide slide;
  final VoidCallback onComboTap;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset((1 - value) * -22, 0),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: onComboTap,
        child: Container(
          width: 236,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(colors: slide.colors),
            boxShadow: [
              BoxShadow(
                color: slide.colors.first.withValues(alpha: 0.24),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: Colors.white.withValues(alpha: 0.22),
                child: Icon(slide.giftIcon, color: Colors.white, size: 17),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '${slide.senderName} sent ${slide.receiverName} ${slide.giftName}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11.5,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'x${slide.combo}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ComboBuzzer extends StatelessWidget {
  const ComboBuzzer({
    super.key,
    required this.slide,
    required this.onTap,
  });

  final GiftSlide? slide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (slide == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.90, end: 1),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutBack,
        builder: (context, value, child) => Transform.scale(scale: value, child: child),
        child: Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [RoomColors.gold, RoomColors.coral]),
            boxShadow: [
              BoxShadow(
                color: RoomColors.coral.withValues(alpha: 0.34),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
              Text(
                'x${slide!.combo}',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, height: 1),
              ),
              const SizedBox(height: 2),
              Text(
                '${slide!.remainingSeconds}s',
                style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900, height: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TinyIconButton extends StatelessWidget {
  const _TinyIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), shape: BoxShape.circle, border: Border.all(color: Colors.white12)),
        child: Icon(icon, color: Colors.white70, size: 17),
      ),
    );
  }
}
