import 'package:flutter/material.dart';

class HomeTopSearchAction extends StatelessWidget {
  const HomeTopSearchAction({
    super.key,
    required this.onSearchTap,
  });

  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      child: Row(
        children: [
          const Spacer(),
          _SearchButton(onTap: onSearchTap),
        ],
      ),
    );
  }
}

class _SearchButton extends StatelessWidget {
  const _SearchButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEDE3D7)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF251538).withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.search_rounded,
            color: Color(0xFF251538),
            size: 24,
          ),
        ),
      ),
    );
  }
}
