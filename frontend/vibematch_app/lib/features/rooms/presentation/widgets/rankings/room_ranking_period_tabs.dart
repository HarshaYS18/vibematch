import 'package:flutter/material.dart';

import 'room_rankings_models.dart';

class RoomRankingPeriodTabs extends StatelessWidget {
  const RoomRankingPeriodTabs({
    super.key,
    required this.selectedPeriod,
    required this.accentColor,
    required this.onChanged,
  });

  final RoomRankingPeriod selectedPeriod;
  final Color accentColor;
  final ValueChanged<RoomRankingPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          for (final period in RoomRankingPeriod.values)
            Expanded(
              child: _RoomRankingPeriodChip(
                period: period,
                selected: period == selectedPeriod,
                accentColor: accentColor,
                onTap: () => onChanged(period),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoomRankingPeriodChip extends StatelessWidget {
  const _RoomRankingPeriodChip({
    required this.period,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  final RoomRankingPeriod period;
  final bool selected;
  final Color accentColor;
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
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: selected
                ? LinearGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.95),
                      const Color(0xFF8C5CF6).withValues(alpha: 0.92),
                    ],
                  )
                : null,
          ),
          child: Text(
            period.label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white.withValues(alpha: 0.64),
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
