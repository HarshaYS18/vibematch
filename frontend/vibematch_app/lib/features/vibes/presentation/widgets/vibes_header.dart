import 'package:flutter/material.dart';

class VibesHeader extends StatelessWidget {
  const VibesHeader({
    super.key,
    required this.onRefreshTap,
    required this.onSettingsTap,
  });

  final VoidCallback onRefreshTap;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Vibes',
              style: TextStyle(
                color: Color(0xFF111015),
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),
          ),
          _HeaderIconButton(icon: Icons.refresh_rounded, onTap: onRefreshTap),
          const SizedBox(width: 8),
          _HeaderIconButton(icon: Icons.settings_rounded, onTap: onSettingsTap),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFECE2D8)),
        ),
        child: Icon(icon, color: const Color(0xFF111015), size: 21),
      ),
    );
  }
}
