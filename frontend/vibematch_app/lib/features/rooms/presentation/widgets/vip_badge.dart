import 'package:flutter/material.dart';

import '../../../../core/assets/vip_svip_tag_assets.dart';

enum VipBadgeSize { tiny, small, medium, large }

class VipBadge extends StatelessWidget {
  const VipBadge({
    super.key,
    required this.level,
    this.size = VipBadgeSize.small,
    this.onTap,
    this.showWhenZero = false,
  });

  final int level;
  final VipBadgeSize size;
  final VoidCallback? onTap;
  final bool showWhenZero;

  int get _safeLevel => level.clamp(0, 50).toInt();

  @override
  Widget build(BuildContext context) {
    if (_safeLevel <= 0 && !showWhenZero) return const SizedBox.shrink();

    final metrics = _VipBadgeMetrics.forSize(size);
    final child = _safeLevel <= 0
        ? _ZeroLevelBadge(metrics: metrics)
        : _AssetBadgeImage(
            assetPath: VipSvipTagAssets.vipTagForLevel(_safeLevel),
            width: metrics.width,
            height: metrics.height,
            fallbackLabel: 'VIP $_safeLevel',
          );

    if (onTap == null) return child;
    return InkWell(
      borderRadius: BorderRadius.circular(metrics.height / 2),
      onTap: onTap,
      child: child,
    );
  }
}

class SvipBadge extends StatelessWidget {
  const SvipBadge({
    super.key,
    required this.level,
    this.size = VipBadgeSize.small,
    this.onTap,
  });

  final int level;
  final VipBadgeSize size;
  final VoidCallback? onTap;

  int get _safeLevel => level.clamp(0, 10).toInt();

  @override
  Widget build(BuildContext context) {
    if (_safeLevel <= 0) return const SizedBox.shrink();

    final metrics = _SvipBadgeMetrics.forSize(size);
    final child = _AssetBadgeImage(
      assetPath: VipSvipTagAssets.svipTagForLevel(_safeLevel),
      width: metrics.width,
      height: metrics.height,
      fallbackLabel: 'SVIP $_safeLevel',
    );

    if (onTap == null) return child;
    return InkWell(
      borderRadius: BorderRadius.circular(metrics.height / 2),
      onTap: onTap,
      child: child,
    );
  }
}

class _AssetBadgeImage extends StatelessWidget {
  const _AssetBadgeImage({
    required this.assetPath,
    required this.width,
    required this.height,
    required this.fallbackLabel,
  });

  final String assetPath;
  final double width;
  final double height;
  final String fallbackLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) =>
            _FallbackBadge(width: width, height: height, label: fallbackLabel),
      ),
    );
  }
}

class _ZeroLevelBadge extends StatelessWidget {
  const _ZeroLevelBadge({required this.metrics});

  final _BadgeMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return _FallbackBadge(
      width: metrics.width,
      height: metrics.height,
      label: 'VIP 0',
      muted: true,
    );
  }
}

class _FallbackBadge extends StatelessWidget {
  const _FallbackBadge({
    required this.width,
    required this.height,
    required this.label,
    this.muted = false,
  });

  final double width;
  final double height;
  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: height * 0.34),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        gradient: muted
            ? const LinearGradient(
                colors: [Color(0xFF3A3342), Color(0xFF7B7282)],
              )
            : const LinearGradient(
                colors: [
                  Color(0xFF120C06),
                  Color(0xFFFFC857),
                  Color(0xFF251538),
                ],
              ),
        border: Border.all(
          color: const Color(0xFFFFD36A).withValues(alpha: muted ? 0.28 : 0.76),
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            color: muted ? const Color(0xFFEDE3D7) : Colors.white,
            fontSize: height * 0.48,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _VipBadgeMetrics extends _BadgeMetrics {
  const _VipBadgeMetrics({required super.width, required super.height});

  static _VipBadgeMetrics forSize(VipBadgeSize size) {
    return switch (size) {
      VipBadgeSize.tiny => const _VipBadgeMetrics(width: 42, height: 17),
      VipBadgeSize.small => const _VipBadgeMetrics(width: 70, height: 28),
      VipBadgeSize.medium => const _VipBadgeMetrics(width: 96, height: 38),
      VipBadgeSize.large => const _VipBadgeMetrics(width: 132, height: 52),
    };
  }
}

class _SvipBadgeMetrics extends _BadgeMetrics {
  const _SvipBadgeMetrics({required super.width, required super.height});

  static _SvipBadgeMetrics forSize(VipBadgeSize size) {
    return switch (size) {
      VipBadgeSize.tiny => const _SvipBadgeMetrics(width: 36, height: 25),
      VipBadgeSize.small => const _SvipBadgeMetrics(width: 58, height: 40),
      VipBadgeSize.medium => const _SvipBadgeMetrics(width: 82, height: 57),
      VipBadgeSize.large => const _SvipBadgeMetrics(width: 110, height: 76),
    };
  }
}

class _BadgeMetrics {
  const _BadgeMetrics({required this.width, required this.height});

  final double width;
  final double height;
}
