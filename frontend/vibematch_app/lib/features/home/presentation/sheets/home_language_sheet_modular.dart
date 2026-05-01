import 'package:flutter/material.dart';

class HomeLanguageSheetModular extends StatelessWidget {
  const HomeLanguageSheetModular({
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
    return _HomeSheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SheetHandle(),
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

class _HomeSheetShell extends StatelessWidget {
  const _HomeSheetShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(18, 10, 18, MediaQuery.paddingOf(context).bottom + 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: child,
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 5,
      decoration: BoxDecoration(
        color: const Color(0xFFE1D8E7),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
