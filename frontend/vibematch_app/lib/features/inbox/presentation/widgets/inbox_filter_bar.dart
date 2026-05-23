import 'package:flutter/material.dart';

import 'inbox_motion.dart';

class InboxFilterBar extends StatelessWidget {
  const InboxFilterBar({
    super.key,
    required this.filters,
    required this.selectedFilter,
    required this.counts,
    required this.onChanged,
  });

  final List<String> filters;
  final String selectedFilter;
  final Map<String, int> counts;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 5, 18, 9),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final selected = filter == selectedFilter;
          final count = counts[filter] ?? 0;
          return _FilterPill(
            label: filter,
            count: count,
            selected: selected,
            onTap: () => onChanged(filter),
          );
        },
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: InboxMotion.standard,
          curve: InboxMotion.curve,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFF251538), Color(0xFF7C3AED)],
                  )
                : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? Colors.white.withValues(alpha: 0.36)
                  : const Color(0xFFE5DDF1),
            ),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? const Color(0xFF7C3AED).withValues(alpha: 0.20)
                    : const Color(0xFF251538).withValues(alpha: 0.045),
                blurRadius: selected ? 18 : 12,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF4A2A63),
                  fontSize: 12.3,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 7),
                Container(
                  constraints: const BoxConstraints(minWidth: 19),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.18)
                        : const Color(0xFFF2EAFE),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF7C3AED),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
