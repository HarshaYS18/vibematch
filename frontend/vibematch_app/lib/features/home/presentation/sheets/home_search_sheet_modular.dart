import 'package:flutter/material.dart';

class HomeSearchSheetModular extends StatefulWidget {
  const HomeSearchSheetModular({
    super.key,
    required this.onMockSearch,
  });

  final ValueChanged<String> onMockSearch;

  @override
  State<HomeSearchSheetModular> createState() => _HomeSearchSheetModularState();
}

class _HomeSearchSheetModularState extends State<HomeSearchSheetModular> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    widget.onMockSearch(query);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(18, 12, 18, MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom + 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFE1D8E7),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Search rooms',
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
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _submit(),
            style: const TextStyle(
              color: Color(0xFF251538),
              fontWeight: FontWeight.w900,
            ),
            decoration: InputDecoration(
              hintText: 'Search room name, language, topic...',
              hintStyle: const TextStyle(
                color: Color(0xFF9B8CA5),
                fontWeight: FontWeight.w700,
              ),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF8C5CF6)),
              filled: true,
              fillColor: const Color(0xFFFAF7F1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: Color(0xFFEDE3D7)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: Color(0xFFEDE3D7)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: Color(0xFF8C5CF6), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF251538),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              onPressed: _submit,
              icon: const Icon(Icons.search_rounded),
              label: const Text(
                'Search',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
