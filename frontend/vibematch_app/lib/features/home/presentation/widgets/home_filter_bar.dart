import 'package:flutter/material.dart';

import '../../models/home_category_model.dart';
import 'home_category_chips.dart';

class HomeFilterBar extends StatelessWidget {
  const HomeFilterBar({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.selectedLanguage,
    required this.onCategorySelected,
    required this.onLanguageTap,
    required this.onSeeAllTap,
  });

  final List<HomeCategoryModel> categories;
  final String selectedCategory;
  final String selectedLanguage;
  final ValueChanged<String> onCategorySelected;
  final VoidCallback onLanguageTap;
  final VoidCallback onSeeAllTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      child: Column(
        children: [
          HomeCategoryChips(
            categories: categories,
            selectedCategory: selectedCategory,
            onCategorySelected: onCategorySelected,
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
                          style: TextStyle(
                            color: Color(0xFF7B6A86),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Flexible(
                          child: Text(
                            selectedLanguage,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF251538),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                            ),
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
                      Text(
                        'See All',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
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
