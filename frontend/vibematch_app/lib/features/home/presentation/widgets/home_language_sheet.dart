import 'package:flutter/material.dart';

import 'home_common_widgets.dart';

class HomeLanguageSheet extends StatelessWidget {
  const HomeLanguageSheet({
    super.key,
    required this.languages,
    required this.selectedLanguage,
    required this.onLanguageSelected,
  });

  final List<String> languages;
  final String selectedLanguage;
  final ValueChanged<String> onLanguageSelected;

  @override
  Widget build(BuildContext context) {
    return HomeSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HomeSheetHandle(),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Room language',
                  style: TextStyle(
                    color: Color(0xFF251538),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Color(0xFF4A2A63)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: languages.length,
              itemBuilder: (context, index) {
                final language = languages[index];
                final selected = language == selectedLanguage;

                return ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  leading: Icon(
                    selected ? Icons.check_circle_rounded : Icons.language_rounded,
                    color: selected ? const Color(0xFF12C7B7) : const Color(0xFF7B6A86),
                  ),
                  title: Text(
                    language,
                    style: TextStyle(
                      color: const Color(0xFF251538),
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                  onTap: () => onLanguageSelected(language),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
