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
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (context, index) => const SizedBox(width: 9),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final selected = category == selectedCategory;

                  return GestureDetector(
                    onTap: () => onCategorySelected(category),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: selected ? const Color(0xFF251538) : Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: selected ? const Color(0xFF251538) : const Color(0xFFEDE3D7),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF251538).withValues(alpha: selected ? 0.13 : 0.04),
                            blurRadius: 14,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          category,
                          style: TextStyle(
                            color: selected ? Colors.white : const Color(0xFF4A2A63),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onLanguageTap,
            child: Container(
              height: 42,
              constraints: const BoxConstraints(minWidth: 48, maxWidth: 118),
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFEDE3D7)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF251538).withValues(alpha: 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.translate_rounded, color: Color(0xFF8C5CF6), size: 19),
                  if (selectedLanguage != 'All') ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        selectedLanguage,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF251538),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 2),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF4A2A63), size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
