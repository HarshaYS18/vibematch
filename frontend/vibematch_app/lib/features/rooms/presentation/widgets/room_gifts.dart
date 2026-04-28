import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'room_theme.dart';

class GiftPanel extends StatefulWidget {
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
  static const List<int> luckyCombos = [9, 69, 99, 999];

  static List<GiftItem> withMockExtras(List<GiftItem> gifts) {
    const extras = <GiftItem>[
      GiftItem(
        id: 'rose_rain',
        name: 'Rose Rain',
        category: GiftCategory.classic,
        coins: 5,
        icon: Icons.local_florist_rounded,
        chatSymbol: '🌹',
        assetPath: 'assets/images/gifts/rose_rain.png',
        colors: [Color(0xFFFF6B9A), Color(0xFFFFC2D8)],
      ),
      GiftItem(
        id: 'star_kiss',
        name: 'Star Kiss',
        category: GiftCategory.classic,
        coins: 15,
        icon: Icons.star_rounded,
        chatSymbol: '⭐',
        assetPath: 'assets/images/gifts/star_kiss.png',
        colors: [Color(0xFFFFD166), Color(0xFFFF8A3D)],
      ),
      GiftItem(
        id: 'music_wave',
        name: 'Music Wave',
        category: GiftCategory.classic,
        coins: 29,
        icon: Icons.music_note_rounded,
        chatSymbol: '🎵',
        assetPath: 'assets/images/gifts/music_wave.png',
        colors: [Color(0xFF12C7B7), Color(0xFF6D5DF6)],
      ),
      GiftItem(
        id: 'lucky_packet',
        name: 'Lucky Packet',
        category: GiftCategory.lucky,
        coins: 39,
        icon: Icons.redeem_rounded,
        chatSymbol: '🧧',
        assetPath: 'assets/images/gifts/lucky_packet.png',
        colors: [Color(0xFFE84C72), Color(0xFFFFB545)],
      ),
      GiftItem(
        id: 'gold_spinner',
        name: 'Gold Spin',
        category: GiftCategory.lucky,
        coins: 59,
        icon: Icons.casino_rounded,
        chatSymbol: '🎰',
        assetPath: 'assets/images/gifts/gold_spinner.png',
        colors: [Color(0xFFFFD166), Color(0xFFC99A3B)],
      ),
      GiftItem(
        id: 'crystal_hunt',
        name: 'Crystal Hunt',
        category: GiftCategory.lucky,
        coins: 89,
        icon: Icons.diamond_rounded,
        chatSymbol: '💠',
        assetPath: 'assets/images/gifts/crystal_hunt.png',
        colors: [Color(0xFF16D9E3), Color(0xFF6D5DF6)],
      ),
      GiftItem(
        id: 'event_firework',
        name: 'Firework',
        category: GiftCategory.event,
        coins: 129,
        icon: Icons.celebration_rounded,
        chatSymbol: '🎆',
        assetPath: 'assets/images/gifts/event_firework.png',
        colors: [Color(0xFFFF7A45), Color(0xFF8C5CF6)],
      ),
      GiftItem(
        id: 'event_trophy',
        name: 'Trophy',
        category: GiftCategory.event,
        coins: 299,
        icon: Icons.emoji_events_rounded,
        chatSymbol: '🏆',
        assetPath: 'assets/images/gifts/event_trophy.png',
        colors: [Color(0xFFFFD166), Color(0xFFFF5F7E)],
      ),
      GiftItem(
        id: 'svip_dragon',
        name: 'SVIP Dragon',
        category: GiftCategory.svip,
        coins: 699,
        icon: Icons.auto_awesome_rounded,
        chatSymbol: '🐉',
        assetPath: 'assets/images/gifts/svip_dragon.png',
        colors: [Color(0xFF8C5CF6), Color(0xFF111827)],
      ),
      GiftItem(
        id: 'svip_throne',
        name: 'SVIP Throne',
        category: GiftCategory.svip,
        coins: 899,
        icon: Icons.chair_rounded,
        chatSymbol: '🪑',
        assetPath: 'assets/images/gifts/svip_throne.png',
        colors: [Color(0xFFFFD166), Color(0xFF8C5CF6)],
      ),
      GiftItem(
        id: 'premium_yacht',
        name: 'Yacht',
        category: GiftCategory.premium,
        coins: 1299,
        icon: Icons.sailing_rounded,
        chatSymbol: '🛥️',
        assetPath: 'assets/images/gifts/premium_yacht.png',
        colors: [Color(0xFF12C7B7), Color(0xFF111827)],
      ),
      GiftItem(
        id: 'premium_castle',
        name: 'Castle',
        category: GiftCategory.premium,
        coins: 1999,
        icon: Icons.castle_rounded,
        chatSymbol: '🏰',
        assetPath: 'assets/images/gifts/premium_castle.png',
        colors: [Color(0xFFC99A3B), Color(0xFF251538)],
      ),
      GiftItem(
        id: 'owned_love_bomb_3',
        name: 'Love x3',
        category: GiftCategory.baggage,
        coins: 0,
        icon: Icons.favorite_rounded,
        chatSymbol: '❤️',
        assetPath: 'assets/images/gifts/love_bomb.png',
        colors: [Color(0xFFFF5F7E), Color(0xFFFFC857)],
      ),
      GiftItem(
        id: 'owned_rocket_1',
        name: 'Rocket x1',
        category: GiftCategory.baggage,
        coins: 0,
        icon: Icons.rocket_launch_rounded,
        chatSymbol: '🚀',
        assetPath: 'assets/images/gifts/rocket.png',
        colors: [Color(0xFF18C7B7), Color(0xFF6C63FF)],
      ),
      GiftItem(
        id: 'owned_event_crown_2',
        name: 'Crown x2',
        category: GiftCategory.baggage,
        coins: 0,
        icon: Icons.workspace_premium_rounded,
        chatSymbol: '👑',
        assetPath: 'assets/images/gifts/royal_crown.png',
        colors: [Color(0xFFFFD166), Color(0xFF111827)],
      ),
    ];

    final seen = gifts.map((gift) => gift.id).toSet();
    return <GiftItem>[
      ...gifts,
      ...extras.where((gift) => seen.add(gift.id)),
    ];
  }

  @override
  State<GiftPanel> createState() => _GiftPanelState();
}

class _GiftPanelState extends State<GiftPanel> {
  late final PageController _categoryPageController;

  @override
  void initState() {
    super.initState();
    _categoryPageController = PageController(
      initialPage: GiftCategory.values.indexOf(widget.selectedCategory),
    );
  }

  @override
  void didUpdateWidget(covariant GiftPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCategory != widget.selectedCategory &&
        _categoryPageController.hasClients) {
      _categoryPageController.animateToPage(
        GiftCategory.values.indexOf(widget.selectedCategory),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _categoryPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allGifts = GiftPanel.withMockExtras(widget.gifts);
    final allSelected = widget.users.isNotEmpty &&
        widget.selectedReceiverIds.length == widget.users.length;
    final comboOptions = widget.selectedCategory == GiftCategory.lucky
        ? GiftPanel.luckyCombos
        : GiftPanel.combos;
    final comboValue = comboOptions.contains(widget.selectedCombo)
        ? widget.selectedCombo
        : comboOptions.first;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.345,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          10,
          7,
          10,
          MediaQuery.paddingOf(context).bottom + 8,
        ),
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
                Expanded(
                  child: _CategoryStrip(
                    selectedCategory: widget.selectedCategory,
                    onChanged: (category) {
                      widget.onCategoryChanged(category);
                      _categoryPageController.animateToPage(
                        GiftCategory.values.indexOf(category),
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                      );
                    },
                  ),
                ),
                _TinyIconButton(
                  icon: Icons.apps_rounded,
                  onTap: () => RoomToast.show(context, 'Store / inventory opened'),
                ),
              ],
            ),
            const SizedBox(height: 7),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.users.length + 1,
                separatorBuilder: (context, index) => const SizedBox(width: 7),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _ReceiverAvatar(
                      selected: allSelected,
                      label: 'All',
                      colors: const [RoomColors.gold, RoomColors.coral],
                      onTap: () => widget.onReceiverToggle('__all__'),
                    );
                  }
                  final user = widget.users[index - 1];
                  return _ReceiverAvatar(
                    selected: widget.selectedReceiverIds.contains(user.id),
                    label: avatarLetter(user.name),
                    colors: user.avatarColors,
                    onTap: () => widget.onReceiverToggle(user.id),
                  );
                },
              ),
            ),
            const SizedBox(height: 7),
            Expanded(
              child: PageView.builder(
                controller: _categoryPageController,
                physics: const BouncingScrollPhysics(),
                itemCount: GiftCategory.values.length,
                onPageChanged: (index) {
                  final category = GiftCategory.values[index];
                  if (category != widget.selectedCategory) widget.onCategoryChanged(category);
                },
                itemBuilder: (context, index) {
                  final category = GiftCategory.values[index];
                  final filtered = allGifts.where((gift) => gift.category == category).toList();

                  return GridView.builder(
                    padding: EdgeInsets.zero,
                    physics: const BouncingScrollPhysics(),
                    itemCount: filtered.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 7,
                      crossAxisSpacing: 7,
                      childAspectRatio: 1,
                    ),
                    itemBuilder: (context, giftIndex) {
                      final gift = filtered[giftIndex];
                      return CompactGiftCard(
                        gift: gift,
                        selected: widget.selectedGift?.id == gift.id,
                        onTap: () => widget.onGiftSelected(gift),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                GestureDetector(
                  onTap: widget.onSend,
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: const LinearGradient(colors: [RoomColors.gold, RoomColors.coral]),
                    ),
                    child: const Center(
                      child: Text('Send', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900)),
                    ),
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
                      value: comboValue,
                      dropdownColor: const Color(0xFF201A2C),
                      iconEnabledColor: Colors.white,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
                      items: comboOptions.map((combo) => DropdownMenuItem(value: combo, child: Text('x$combo'))).toList(),
                      onChanged: (value) {
                        if (value != null) widget.onComboChanged(value);
                      },
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: widget.onRecharge,
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
                        Text('${widget.coinBalance}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
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

class GiftVisual extends StatelessWidget {
  const GiftVisual({
    super.key,
    required this.icon,
    required this.colors,
    this.assetPath,
    this.size = 36,
    this.padding = 5,
  });

  final IconData icon;
  final List<Color> colors;
  final String? assetPath;
  final double size;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final visual = assetPath == null
        ? null
        : Image.asset(
            assetPath!,
            width: size - padding,
            height: size - padding,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) => Icon(icon, color: Colors.white, size: size * 0.46),
          );

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: colors),
        border: Border.all(color: Colors.white.withValues(alpha: 0.34), width: 0.9),
        boxShadow: [
          BoxShadow(color: colors.first.withValues(alpha: 0.35), blurRadius: size * 0.38, offset: Offset(0, size * 0.12)),
          BoxShadow(color: Colors.white.withValues(alpha: 0.16), blurRadius: size * 0.22, spreadRadius: 0.5),
        ],
      ),
      child: ClipOval(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.34),
                      Colors.white.withValues(alpha: 0.04),
                      Colors.black.withValues(alpha: 0.07),
                    ],
                  ),
                ),
              ),
            ),
            visual ?? Icon(icon, color: Colors.white, size: size * 0.46),
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
        separatorBuilder: (context, index) => const SizedBox(width: 5),
        itemBuilder: (context, index) {
          final category = GiftCategory.values[index];
          final selected = category == selectedCategory;
          return GestureDetector(
            onTap: () => onChanged(category),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 9),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? RoomColors.gold : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: selected ? Colors.white.withValues(alpha: 0.26) : Colors.white.withValues(alpha: 0.06)),
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
    final isOwned = gift.category == GiftCategory.baggage;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: selected ? 0.15 : 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? gift.colors.first : Colors.white12, width: selected ? 1.6 : 1),
          boxShadow: selected
              ? [BoxShadow(color: gift.colors.first.withValues(alpha: 0.20), blurRadius: 10, offset: const Offset(0, 4))]
              : null,
        ),
        child: Column(
          children: [
            GiftVisual(icon: gift.icon, colors: gift.colors, assetPath: gift.assetPath, size: 30, padding: 2),
            const SizedBox(height: 3),
            Text(gift.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 9.7, fontWeight: FontWeight.w900)),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isOwned ? Icons.inventory_2_rounded : Icons.toll_rounded, color: isOwned ? RoomColors.aqua : RoomColors.gold, size: 10),
                const SizedBox(width: 2),
                Text(isOwned ? 'Owned' : '${gift.coins}', style: TextStyle(color: isOwned ? RoomColors.aqua : RoomColors.gold, fontSize: 9.4, fontWeight: FontWeight.w900)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class GiftSlideStack extends StatelessWidget {
  const GiftSlideStack({super.key, required this.slides, required this.onComboTap});

  final List<GiftSlide> slides;
  final ValueChanged<GiftSlide> onComboTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: slides.take(2).map((slide) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: GiftSlideCard(slide: slide, onComboTap: () => onComboTap(slide)),
        );
      }).toList(),
    );
  }
}

class GiftSlideCard extends StatelessWidget {
  const GiftSlideCard({super.key, required this.slide, required this.onComboTap});

  final GiftSlide slide;
  final VoidCallback onComboTap;

  @override
  Widget build(BuildContext context) {
    final dismissProgress = slide.remainingSeconds <= 2 ? (2 - slide.remainingSeconds) / 2 : 0.0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: dismissProgress, end: dismissProgress),
      duration: const Duration(seconds: 2),
      curve: Curves.easeInOutCubic,
      builder: (context, value, child) {
        final opacity = (1 - value).clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(value * 130, 0),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: onComboTap,
        child: Container(
          width: 252,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.36),
                slide.colors.first.withValues(alpha: 0.58),
                slide.colors.last.withValues(alpha: 0.44),
                Colors.black.withValues(alpha: 0.18),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.42), width: 1.15),
            boxShadow: [
              BoxShadow(color: slide.colors.first.withValues(alpha: 0.36), blurRadius: 22, offset: const Offset(0, 10)),
              BoxShadow(color: Colors.white.withValues(alpha: 0.22), blurRadius: 16, spreadRadius: 1.0),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.26),
                          Colors.white.withValues(alpha: 0.05),
                          Colors.white.withValues(alpha: 0.16),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: -40,
                  top: -22,
                  child: Transform.rotate(
                    angle: -0.45,
                    child: Container(
                      width: 46,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.0),
                            Colors.white.withValues(alpha: 0.42),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    GiftVisual(icon: slide.giftIcon, colors: slide.colors, assetPath: slide.giftAssetPath, size: 38, padding: 2),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${slide.senderName} sent ${slide.receiverName} ${slide.giftName}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, height: 1.1, shadows: [Shadow(color: Colors.black38, blurRadius: 6)]),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.34)),
                      ),
                      child: Text('x${slide.combo}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ComboBuzzer extends StatelessWidget {
  const ComboBuzzer({super.key, required this.slide, required this.onTap});

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
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [RoomColors.gold, RoomColors.coral]),
            boxShadow: [BoxShadow(color: RoomColors.coral.withValues(alpha: 0.34), blurRadius: 18, offset: const Offset(0, 8))],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
              Text('x${slide!.combo}', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, height: 1)),
              const SizedBox(height: 3),
              Text('${slide!.remainingSeconds}s', style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w900, height: 1)),
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
