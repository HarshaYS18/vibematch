import 'package:flutter/material.dart';

import 'inbox_motion.dart';

class InboxSearchBar extends StatelessWidget {
  const InboxSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.expanded,
    required this.onToggle,
    required this.onClear,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onClear;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: InboxMotion.standard,
      curve: InboxMotion.curve,
      height: expanded ? 58 : 0,
      margin: EdgeInsets.fromLTRB(18, expanded ? 4 : 0, 18, expanded ? 10 : 0),
      child: AnimatedOpacity(
        duration: InboxMotion.quick,
        opacity: expanded ? 1 : 0,
        child: IgnorePointer(
          ignoring: !expanded,
          child: Material(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(22),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                color: Color(0xFF251538),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
              decoration: InputDecoration(
                hintText: 'Search conversations',
                hintStyle: const TextStyle(
                  color: Color(0xFF9B8CA5),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF7C3AED),
                ),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, child) {
                    if (value.text.trim().isNotEmpty) {
                      return IconButton(
                        onPressed: onClear,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF7B6A86),
                        ),
                      );
                    }
                    return IconButton(
                      onPressed: onToggle,
                      icon: const Icon(
                        Icons.keyboard_arrow_up_rounded,
                        color: Color(0xFF7B6A86),
                      ),
                    );
                  },
                ),
                filled: true,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 17,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: Color(0xFFE5DDF1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: Color(0xFFE5DDF1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(
                    color: Color(0xFF12C7B7),
                    width: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
