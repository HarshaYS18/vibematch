import 'package:flutter/material.dart';

import '../../models/home_highlight_model.dart';

class HomeHighlightsCarousel extends StatelessWidget {
  const HomeHighlightsCarousel({
    super.key,
    required this.highlights,
    required this.selectedIndex,
    required this.canManageHighlights,
    required this.onPageChanged,
    required this.onHighlightTap,
    required this.onManageTap,
  });

  final List<HomeHighlightModel> highlights;
  final int selectedIndex;
  final bool canManageHighlights;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<HomeHighlightModel> onHighlightTap;
  final VoidCallback onManageTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 8, 18, 18),
      height: 166,
      child: PageView.builder(
        itemCount: highlights.length,
        onPageChanged: onPageChanged,
        itemBuilder: (context, index) {
          final item = highlights[index];
          return GestureDetector(
            onTap: () => onHighlightTap(item),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: item.gradient,
                ),
                boxShadow: [
                  BoxShadow(
                    color: item.gradient.first.withValues(alpha: 0.25),
                    blurRadius: 26,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -8,
                    bottom: -18,
                    child: Icon(
                      item.icon,
                      size: 112,
                      color: Colors.white.withValues(alpha: 0.13),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.17),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Official Highlight',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        item.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 12.5,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          ...List.generate(
                            highlights.length,
                            (dotIndex) => AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.only(right: 5),
                              width: dotIndex == selectedIndex ? 18 : 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(
                                  alpha: dotIndex == selectedIndex ? 0.95 : 0.38,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (canManageHighlights)
                            GestureDetector(
                              onTap: onManageTap,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.17),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 14),
                                    SizedBox(width: 5),
                                    Text(
                                      'Manage',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
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
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
