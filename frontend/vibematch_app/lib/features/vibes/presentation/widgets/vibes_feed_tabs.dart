import 'package:flutter/material.dart';

import '../../models/vibe_models.dart';

class VibesFeedTabs extends StatelessWidget {
  const VibesFeedTabs({
    super.key,
    required this.selectedTab,
    required this.onChanged,
  });

  final VibesFeedTab selectedTab;
  final ValueChanged<VibesFeedTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        height: 48,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFECE2D8))),
        ),
        child: Row(
          children: VibesFeedTab.values.map((tab) {
            final selected = tab == selectedTab;
            return Expanded(
              child: InkWell(
                onTap: () => onChanged(tab),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: selected ? const Color(0xFF111015) : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                  child: Text(
                    tab.label,
                    style: TextStyle(
                      color: selected ? const Color(0xFF111015) : const Color(0xFF8C8198),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
