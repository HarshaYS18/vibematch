import 'package:flutter/material.dart';

import '../widgets/create_ui_helpers.dart';

class CreateLanguageSheet extends StatelessWidget {
  const CreateLanguageSheet({
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
    return CreateSheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CreateSheetHandle(),
          const SizedBox(height: 14),
          const Text(
            'Choose room language',
            style: TextStyle(
              color: Color(0xFF251538),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: languages.length,
              itemBuilder: (context, index) {
                final language = languages[index];
                final selected = language == selectedLanguage;

                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  leading: Icon(
                    selected ? Icons.check_circle_rounded : Icons.language_rounded,
                    color: selected ? const Color(0xFF12C7B7) : const Color(0xFF6A5877),
                  ),
                  title: Text(
                    language,
                    style: TextStyle(
                      color: const Color(0xFF251538),
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                  onTap: () {
                    onLanguageSelected(language);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
