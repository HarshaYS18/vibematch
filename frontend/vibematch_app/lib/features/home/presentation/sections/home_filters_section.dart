import 'package:flutter/material.dart';

class HomeFiltersSection extends StatelessWidget {
  const HomeFiltersSection({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.selectedLanguage,
    required this.onCategorySelected,
    required this.onLanguageTap,
  });

  final List<String> categories;
  final String selectedCategory;
  final String selectedLanguage;
  final ValueChanged<String> onCategorySelected;
  final VoidCallback onLanguageTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 12),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 34,
              child: Row(
                children: categories.map((category) {
                  final selected = category == selectedCategory;
                  return Padding(
                    padding: const EdgeInsets.only(right: 26),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onCategorySelected(category),
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 170),
                        curve: Curves.easeOutCubic,
                        style: TextStyle(
                          color: selected ? const Color(0xFF251538) : const Color(0xFF7B6A86),
                          fontSize: selected ? 15 : 14,
                          height: 1,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                          letterSpacing: -0.15,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(category),
                            const SizedBox(height: 6),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              width: selected ? 28 : 0,
                              height: 3,
                              decoration: BoxDecoration(
                                color: const Color(0xFF12C7B7),
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF12C7B7).withValues(alpha: 0.34),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(growable: false),
              ),
            ),
          ),
          GestureDetector(
            onTap: onLanguageTap,
            child: Container(
              height: 30,
              constraints: const BoxConstraints(minWidth: 42, maxWidth: 108),
              padding: const EdgeInsets.symmetric(horizontal: 9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFEDE3D7)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.translate_rounded, color: Color(0xFF8C5CF6), size: 16),
                  if (selectedLanguage != 'All') ...[
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        selectedLanguage,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF251538),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 1),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF4A2A63), size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
