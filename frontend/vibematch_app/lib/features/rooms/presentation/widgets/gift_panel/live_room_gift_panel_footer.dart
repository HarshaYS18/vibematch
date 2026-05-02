import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../live_room_models.dart';
import '../room_theme.dart';

class LiveRoomGiftPanelFooter extends StatelessWidget {
  const LiveRoomGiftPanelFooter({
    super.key,
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
    return RepaintBoundary(
      child: Row(
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
      ),
    );
  }
}
