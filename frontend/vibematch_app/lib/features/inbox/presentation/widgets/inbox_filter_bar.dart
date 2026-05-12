import 'package:flutter/material.dart';

class InboxFilterBar extends StatelessWidget {
  const InboxFilterBar({
    super.key,
    required this.filters,
    required this.selectedFilter,
    required this.onChanged,
  });

  final List<String> filters;
  final String selectedFilter;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: Colors.white,
      alignment: Alignment.centerLeft,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final selected = filter == selectedFilter;

          return InkWell(
            onTap: () => onChanged(filter),
            borderRadius: BorderRadius.circular(999),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFE7FCEB) : const Color(0xFFF0F2F5),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected ? const Color(0xFFC8F2D1) : const Color(0xFFF0F2F5),
                ),
              ),
              child: Center(
                child: Text(
                  filter,
                  style: TextStyle(
                    color: selected ? const Color(0xFF008069) : const Color(0xFF54656F),
                    fontSize: 12.2,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.05,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
