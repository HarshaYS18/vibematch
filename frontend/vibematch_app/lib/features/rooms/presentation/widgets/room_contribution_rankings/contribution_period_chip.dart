import 'package:flutter/material.dart';

import '../room_theme.dart';

class ContributionPeriodChip extends StatelessWidget {
  const ContributionPeriodChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: selected ? const LinearGradient(colors: [RoomColors.violet, RoomColors.aqua]) : null,
            color: selected ? null : RoomColors.pearl,
            border: Border.all(color: selected ? Colors.transparent : RoomColors.softLine),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : RoomColors.plum,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
