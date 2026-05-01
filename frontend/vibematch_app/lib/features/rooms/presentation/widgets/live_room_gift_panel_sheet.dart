import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'room_gifts.dart';
import 'room_theme.dart';

class LiveRoomGiftPanelSheet extends StatefulWidget {
  const LiveRoomGiftPanelSheet({
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

  @override
  State<LiveRoomGiftPanelSheet> createState() => _LiveRoomGiftPanelSheetState();
}

class _LiveRoomGiftPanelSheetState extends State<LiveRoomGiftPanelSheet> {
  late final PageController _pageController;
  late final List<GiftItem> _allGifts;

  late final ValueNotifier<GiftCategory> _categoryNotifier;
  late final ValueNotifier<GiftItem?> _giftNotifier;
  late final ValueNotifier<int> _comboNotifier;
  late final ValueNotifier<Set<String>> _receiversNotifier;

  @override
  void initState() {
    super.initState();
    _allGifts = GiftPanel.withMockExtras(widget.gifts);
    _categoryNotifier = ValueNotifier<GiftCategory>(widget.selectedCategory);
    _giftNotifier = ValueNotifier<GiftItem?>(widget.selectedGift ?? _firstGiftForCategory(widget.selectedCategory));
    _comboNotifier = ValueNotifier<int>(widget.selectedCombo);
    _receiversNotifier = ValueNotifier<Set<String>>(Set<String>.from(widget.selectedReceiverIds));
    _pageController = PageController(
      initialPage: GiftCategory.values.indexOf(widget.selectedCategory),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _categoryNotifier.dispose();
    _giftNotifier.dispose();
    _comboNotifier.dispose();
    _receiversNotifier.dispose();
    super.dispose();
  }

  GiftItem? _firstGiftForCategory(GiftCategory category) {
    for (final gift in _allGifts) {
      if (gift.category == category) return gift;
    }
    return null;
  }

  int _defaultComboFor(GiftCategory category) {
    return category == GiftCategory.lucky ? 9 : 1;
  }

  List<int> _comboOptionsFor(GiftCategory category) {
    return category == GiftCategory.lucky ? GiftPanel.luckyCombos : GiftPanel.combos;
  }

  void _selectCategory(GiftCategory category, {bool animatePage = true}) {
    if (_categoryNotifier.value == category) return;

    final gift = _firstGiftForCategory(category);
    final combo = _defaultComboFor(category);

    _categoryNotifier.value = category;
    _giftNotifier.value = gift;
    _comboNotifier.value = combo;

    widget.onCategoryChanged(category);
    if (gift != null) widget.onGiftSelected(gift);
    widget.onComboChanged(combo);

    if (animatePage && _pageController.hasClients) {
      _pageController.animateToPage(
        GiftCategory.values.indexOf(category),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _selectGift(GiftItem gift) {
    final combo = gift.isVideoGift ? 1 : _defaultComboFor(gift.category);

    _giftNotifier.value = gift;
    _categoryNotifier.value = gift.category;
    _comboNotifier.value = combo;

    widget.onGiftSelected(gift);
    widget.onComboChanged(combo);
  }

  void _toggleReceiver(String id) {
    widget.onReceiverToggle(id);

    final current = Set<String>.from(_receiversNotifier.value);
    if (id == '__all__') {
      final allSelected = widget.users.isNotEmpty && current.length == widget.users.length;
      current
        ..clear()
        ..addAll(allSelected ? const <String>[] : widget.users.map((user) => user.id));
    } else if (current.contains(id)) {
      current.remove(id);
    } else {
      current.add(id);
    }
    _receiversNotifier.value = current;
  }

  void _changeCombo(int combo) {
    final selectedGift = _giftNotifier.value;
    final safeCombo = selectedGift?.isVideoGift ?? false ? 1 : combo;
    _comboNotifier.value = safeCombo;
    widget.onComboChanged(safeCombo);
  }

  @override
  Widget build(BuildContext context) {
    final panelHeight = MediaQuery.sizeOf(context).height * 0.38;

    return SizedBox(
      height: panelHeight,
      child: RepaintBoundary(
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
              _GiftPanelHeader(
                selectedCategoryListenable: _categoryNotifier,
                onCategoryChanged: _selectCategory,
                onStoreTap: () => RoomToast.show(context, 'Store / inventory opened'),
              ),
              const SizedBox(height: 7),
              _GiftReceiverStrip(
                users: widget.users,
                selectedReceiverIdsListenable: _receiversNotifier,
                onReceiverToggle: _toggleReceiver,
              ),
              const SizedBox(height: 7),
              Expanded(
                child: RepaintBoundary(
                  child: _GiftCategoryPager(
                    pageController: _pageController,
                    allGifts: _allGifts,
                    selectedCategoryListenable: _categoryNotifier,
                    selectedGiftListenable: _giftNotifier,
                    onPageChanged: (category) => _selectCategory(category, animatePage: false),
                    onGiftSelected: _selectGift,
                  ),
                ),
              ),
              const SizedBox(height: 7),
              _GiftPanelFooter(
                selectedCategoryListenable: _categoryNotifier,
                selectedGiftListenable: _giftNotifier,
                comboListenable: _comboNotifier,
                coinBalance: widget.coinBalance,
                comboOptionsFor: _comboOptionsFor,
                onComboChanged: _changeCombo,
                onSend: widget.onSend,
                onRecharge: widget.onRecharge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GiftPanelHeader extends StatelessWidget {
  const _GiftPanelHeader({
    required this.selectedCategoryListenable,
    required this.onCategoryChanged,
    required this.onStoreTap,
  });

  final ValueListenable<GiftCategory> selectedCategoryListenable;
  final ValueChanged<GiftCategory> onCategoryChanged;
  final VoidCallback onStoreTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.card_giftcard_rounded, color: RoomColors.gold, size: 18),
        const SizedBox(width: 6),
        const Text(
          'Gifts',
          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ValueListenableBuilder<GiftCategory>(
            valueListenable: selectedCategoryListenable,
            builder: (context, category, _) {
              return _CategoryStripOptimized(
                selectedCategory: category,
                onChanged: onCategoryChanged,
              );
            },
          ),
        ),
        _TinyIconButton(icon: Icons.apps_rounded, onTap: onStoreTap),
      ],
    );
  }
}

class _CategoryStripOptimized extends StatelessWidget {
  const _CategoryStripOptimized({required this.selectedCategory, required this.onChanged});

  final GiftCategory selectedCategory;
  final ValueChanged<GiftCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
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
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? RoomColors.gold : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.26)
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Text(
                category.label,
                style: TextStyle(
                  color: selected ? RoomColors.deep : Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GiftReceiverStrip extends StatelessWidget {
  const _GiftReceiverStrip({
    required this.users,
    required this.selectedReceiverIdsListenable,
    required this.onReceiverToggle,
  });

  final List<SeatUser> users;
  final ValueListenable<Set<String>> selectedReceiverIdsListenable;
  final ValueChanged<String> onReceiverToggle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ValueListenableBuilder<Set<String>>(
        valueListenable: selectedReceiverIdsListenable,
        builder: (context, selectedIds, _) {
          final allSelected = users.isNotEmpty && selectedIds.length == users.length;
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: users.length + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 7),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _ReceiverAvatarOptimized(
                  selected: allSelected,
                  label: 'All',
                  colors: const [RoomColors.gold, RoomColors.coral],
                  onTap: () => onReceiverToggle('__all__'),
                );
              }
              final user = users[index - 1];
              return _ReceiverAvatarOptimized(
                selected: selectedIds.contains(user.id),
                label: avatarLetter(user.name),
                colors: user.avatarColors,
                onTap: () => onReceiverToggle(user.id),
              );
            },
          );
        },
      ),
    );
  }
}

class _ReceiverAvatarOptimized extends StatelessWidget {
  const _ReceiverAvatarOptimized({
    required this.selected,
    required this.label,
    required this.colors,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 36,
        height: 36,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? RoomColors.gold : Colors.white24,
            width: selected ? 2 : 1,
          ),
        ),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: colors),
          ),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

class _GiftCategoryPager extends StatelessWidget {
  const _GiftCategoryPager({
    required this.pageController,
    required this.allGifts,
    required this.selectedCategoryListenable,
    required this.selectedGiftListenable,
    required this.onPageChanged,
    required this.onGiftSelected,
  });

  final PageController pageController;
  final List<GiftItem> allGifts;
  final ValueListenable<GiftCategory> selectedCategoryListenable;
  final ValueListenable<GiftItem?> selectedGiftListenable;
  final ValueChanged<GiftCategory> onPageChanged;
  final ValueChanged<GiftItem> onGiftSelected;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GiftItem?>(
      valueListenable: selectedGiftListenable,
      builder: (context, selectedGift, _) {
        return PageView.builder(
          controller: pageController,
          physics: const BouncingScrollPhysics(),
          itemCount: GiftCategory.values.length,
          onPageChanged: (index) => onPageChanged(GiftCategory.values[index]),
          itemBuilder: (context, index) {
            final category = GiftCategory.values[index];
            final filtered = allGifts.where((gift) => gift.category == category).toList(growable: false);
            return GridView.builder(
              key: PageStorageKey<String>('gift-grid-${category.name}'),
              padding: EdgeInsets.zero,
              physics: const BouncingScrollPhysics(),
              itemCount: filtered.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.95,
              ),
              itemBuilder: (context, giftIndex) {
                final gift = filtered[giftIndex];
                return CompactGiftCard(
                  gift: gift,
                  selected: selectedGift?.id == gift.id,
                  onTap: () => onGiftSelected(gift),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _GiftPanelFooter extends StatelessWidget {
  const _GiftPanelFooter({
    required this.selectedCategoryListenable,
    required this.selectedGiftListenable,
    required this.comboListenable,
    required this.coinBalance,
    required this.comboOptionsFor,
    required this.onComboChanged,
    required this.onSend,
    required this.onRecharge,
  });

  final ValueListenable<GiftCategory> selectedCategoryListenable;
  final ValueListenable<GiftItem?> selectedGiftListenable;
  final ValueListenable<int> comboListenable;
  final int coinBalance;
  final List<int> Function(GiftCategory category) comboOptionsFor;
  final ValueChanged<int> onComboChanged;
  final VoidCallback onSend;
  final VoidCallback onRecharge;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onSend,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 17),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(colors: [RoomColors.gold, RoomColors.coral]),
            ),
            child: const Center(
              child: Text(
                'Send',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ValueListenableBuilder<GiftCategory>(
          valueListenable: selectedCategoryListenable,
          builder: (context, category, _) {
            return ValueListenableBuilder<GiftItem?>(
              valueListenable: selectedGiftListenable,
              builder: (context, gift, _) {
                return ValueListenableBuilder<int>(
                  valueListenable: comboListenable,
                  builder: (context, combo, _) {
                    final options = gift?.isVideoGift ?? false ? const [1] : comboOptionsFor(category);
                    final comboValue = options.contains(combo) ? combo : options.first;
                    return Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: comboValue,
                          dropdownColor: const Color(0xFF201A2C),
                          iconEnabledColor: Colors.white,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                          items: options
                              .map((option) => DropdownMenuItem<int>(
                                    value: option,
                                    child: Text('x$option'),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) onComboChanged(value);
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
        const Spacer(),
        GestureDetector(
          onTap: onRecharge,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                const Icon(Icons.add_circle_rounded, color: RoomColors.aqua, size: 17),
                const SizedBox(width: 5),
                const Icon(Icons.toll_rounded, color: RoomColors.gold, size: 15),
                const SizedBox(width: 4),
                Text(
                  '$coinBalance',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ),
      ],
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
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon, color: Colors.white, size: 17),
      ),
    );
  }
}
