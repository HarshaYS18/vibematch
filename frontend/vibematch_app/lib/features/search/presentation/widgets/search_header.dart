import 'package:flutter/material.dart';

class SearchHeader extends StatelessWidget {
  const SearchHeader({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hasQuery,
    required this.onBackTap,
    required this.onClearTap,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasQuery;
  final VoidCallback onBackTap;
  final VoidCallback onClearTap;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
        border: const Border(bottom: BorderSide(color: Color(0xFFECE2D8))),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF251538).withValues(alpha: 0.055),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _RoundButton(icon: Icons.arrow_back_rounded, onTap: onBackTap),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 46,
              padding: const EdgeInsets.only(left: 13, right: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFEDE3D7)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: Color(0xFF8C5CF6), size: 21),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      textInputAction: TextInputAction.search,
                      onChanged: onChanged,
                      onSubmitted: onSubmitted,
                      style: const TextStyle(
                        color: Color(0xFF251538),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Search users, rooms, vibes...',
                        hintStyle: TextStyle(
                          color: Color(0xFF9B8CA5),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (hasQuery)
                    InkWell(
                      onTap: onClearTap,
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF251538).withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, color: Color(0xFF4A2A63), size: 18),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFECE2D8)),
          ),
          child: Icon(icon, color: const Color(0xFF251538), size: 21),
        ),
      ),
    );
  }
}
