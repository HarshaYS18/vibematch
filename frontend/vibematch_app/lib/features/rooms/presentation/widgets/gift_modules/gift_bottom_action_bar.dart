import 'package:flutter/material.dart';

import '../economy/gold_coin_icon.dart';
import '../room_theme.dart';

class GiftBottomActionBar extends StatelessWidget {
  const GiftBottomActionBar({
    super.key,
    required this.comboValue,
    required this.comboOptions,
    required this.coinBalance,
    required this.onSend,
    required this.onComboChanged,
    required this.onRecharge,
  });

  final int comboValue;
  final List<int> comboOptions;
  final int coinBalance;
  final VoidCallback onSend;
  final ValueChanged<int> onComboChanged;
  final VoidCallback onRecharge;

  @override
  Widget build(BuildContext context) {
    return Row(
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
              value: comboValue,
              dropdownColor: const Color(0xFF201A2C),
              iconEnabledColor: Colors.white,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
              items: comboOptions.map((combo) => DropdownMenuItem(value: combo, child: Text('x$combo'))).toList(),
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
                const GoldCoinIcon(size: 15),
                const SizedBox(width: 4),
                Text('$coinBalance', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
