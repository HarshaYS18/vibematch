import 'package:flutter/material.dart';

import '../../../../foundation/images/app_image.dart';

import '../../models/vibe_models.dart';

class VibeAvatar extends StatelessWidget {
  const VibeAvatar({super.key, required this.vibe, required this.size});

  final VibeItem vibe;
  final double size;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = vibe.avatarUrl?.trim();
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: vibe.colors),
      ),
      child: avatarUrl != null && avatarUrl.isNotEmpty
          ? AppImage.network(
              avatarUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              fallback: _FallbackAvatar(vibe: vibe),
            )
          : _FallbackAvatar(vibe: vibe),
    );
  }
}

class _FallbackAvatar extends StatelessWidget {
  const _FallbackAvatar({required this.vibe});

  final VibeItem vibe;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        vibe.avatarText,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 15,
        ),
      ),
    );
  }
}
