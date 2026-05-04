import 'package:flutter/material.dart';

class HomeFilterBar extends StatelessWidget {
  const HomeFilterBar({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.selectedLanguage,
    required this.onCategoryTap,
    required this.onLanguageTap,
    required this.onSeeAllTap,
  });

  final List<String> categories;
  final String selectedCategory;
  final String selectedLanguage;
  final ValueChanged<String> onCategoryTap;
  final VoidCallback onLanguageTap;
  final VoidCallback onSeeAllTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      child: Column(
        children: [
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 9),
              itemBuilder: (context, index) {
                final category = categories[index];
                final selected = category == selectedCategory;

                return GestureDetector(
                  onTap: () => onCategoryTap(category),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 15),
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onLanguageTap,
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFEDE3D7)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.language_rounded, color: Color(0xFF8C5CF6), size: 20),
                        const SizedBox(width: 9),
                        const Text(
                          'Language',
                          style: TextStyle(color: Color(0xFF7B6A86), fontSize: 12.5, fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        Flexible(
                          child: Text(
                            selectedLanguage,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFF251538), fontSize: 12.5, fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF4A2A63)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onSeeAllTap,
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(
                    color: const Color(0xFF12C7B7),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF12C7B7).withValues(alpha: 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.all_inclusive_rounded, color: Colors.white, size: 19),
                      SizedBox(width: 6),
                      Text('See All', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
