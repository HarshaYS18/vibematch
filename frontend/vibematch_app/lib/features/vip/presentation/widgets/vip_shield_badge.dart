import 'package:flutter/material.dart';

import '../../../../core/assets/vip_svip_tag_assets.dart';

class VipShieldBadge extends StatelessWidget {
  const VipShieldBadge({super.key, required this.level, this.size = 58});

  final int level;
  final double size;

  int get _safeLevel => level.clamp(1, 50).toInt();

  @override
  Widget build(BuildContext context) {
    final width = size * 1.85;
    final height = size * 0.72;

    return SizedBox(
      width: width,
      height: height,
      child: Image.asset(
        VipSvipTagAssets.vipTagForLevel(_safeLevel),
        width: width,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: height * 0.34),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height / 2),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF120C06),
                  Color(0xFFFFC857),
                  Color(0xFF251538),
                ],
              ),
              border: Border.all(color: const Color(0xFFFFD36A), width: 1.2),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'VIP $_safeLevel',
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
