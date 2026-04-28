import 'dart:math' as math;

import 'package:flutter/material.dart';

enum VipBadgeSize { tiny, small, medium, large }

enum _VipBadgeTier { silver, blackGold, red, blue, green, purple }

class VipBadge extends StatefulWidget {
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

  @override
  State<VipBadge> createState() => _VipBadgeState();
}

class _VipBadgeState extends State<VipBadge>
    with SingleTickerProviderStateMixin {
  static const String _assetBase = 'assets/images/vip_badges';

  late final AnimationController _shineController;

  int get _safeLevel => widget.level.clamp(0, 50).toInt();
  bool get _visible => widget.level > 0 || widget.showWhenZero;
  bool get _premiumShine => _safeLevel >= 30;

  _VipBadgeTier get _tier {
    final value = _safeLevel;

    if (value >= 41) return _VipBadgeTier.purple;
    if (value >= 30) return _VipBadgeTier.green;
    if (value >= 21) return _VipBadgeTier.blue;
    if (value >= 11) return _VipBadgeTier.red;
    if (value >= 6) return _VipBadgeTier.blackGold;
    return _VipBadgeTier.silver;
  }

  String get _assetPath {
    return switch (_tier) {
      _VipBadgeTier.silver => '$_assetBase/vip_silver.png',
      _VipBadgeTier.blackGold => '$_assetBase/vip_black_gold.png',
      _VipBadgeTier.red => '$_assetBase/vip_red.png',
      _VipBadgeTier.blue => '$_assetBase/vip_blue.png',
      _VipBadgeTier.green => '$_assetBase/vip_green.png',
      _VipBadgeTier.purple => '$_assetBase/vip_purple.png',
    };
  }

  List<Color> get _pillGradient {
    return switch (_tier) {
      _VipBadgeTier.silver => const [
          Color(0xFF17191E),
          Color(0xFF7D828B),
          Color(0xFFE7E9ED),
          Color(0xFF282D35),
        ],
      _VipBadgeTier.blackGold => const [
          Color(0xFF080704),
          Color(0xFF332306),
          Color(0xFFD9A735),
          Color(0xFF120C06),
        ],
      _VipBadgeTier.red => const [
          Color(0xFF260304),
          Color(0xFF8E0C15),
          Color(0xFFFF4857),
          Color(0xFF4C060B),
        ],
      _VipBadgeTier.blue => const [
          Color(0xFF041226),
          Color(0xFF0B4E9E),
          Color(0xFF28B9FF),
          Color(0xFF061A3B),
        ],
      _VipBadgeTier.green => const [
          Color(0xFF031C11),
          Color(0xFF08703E),
          Color(0xFF21EA8B),
          Color(0xFF052716),
        ],
      _VipBadgeTier.purple => const [
          Color(0xFF190529),
          Color(0xFF5C159A),
          Color(0xFFC84DFF),
          Color(0xFF260736),
        ],
    };
  }

  Color get _glowColor {
    return switch (_tier) {
      _VipBadgeTier.silver => const Color(0xFFDDE1E8),
      _VipBadgeTier.blackGold => const Color(0xFFFFC64C),
      _VipBadgeTier.red => const Color(0xFFFF4D5D),
      _VipBadgeTier.blue => const Color(0xFF27B7FF),
      _VipBadgeTier.green => const Color(0xFF20FF99),
      _VipBadgeTier.purple => const Color(0xFFD65AFF),
    };
  }

  double get _height {
    return switch (widget.size) {
      VipBadgeSize.tiny => 21,
      VipBadgeSize.small => 31,
      VipBadgeSize.medium => 42,
      VipBadgeSize.large => 56,
    };
  }

  double get _pillWidth {
    return switch (widget.size) {
      VipBadgeSize.tiny => 51,
      VipBadgeSize.small => 72,
      VipBadgeSize.medium => 95,
      VipBadgeSize.large => 126,
    };
  }

  double get _badgeSize {
    return switch (widget.size) {
      VipBadgeSize.tiny => 32,
      VipBadgeSize.small => 47,
      VipBadgeSize.medium => 64,
      VipBadgeSize.large => 86,
    };
  }

  double get _fontSize {
    return switch (widget.size) {
      VipBadgeSize.tiny => 8.2,
      VipBadgeSize.small => 10.4,
      VipBadgeSize.medium => 13.6,
      VipBadgeSize.large => 18,
    };
  }

  double get _totalWidth => _pillWidth + (_badgeSize * 0.58);

  @override
  void initState() {
    super.initState();
    _shineController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _premiumShine ? 1700 : 3000),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant VipBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPremium = oldWidget.level >= 30;

    if (oldPremium != _premiumShine || oldWidget.size != widget.size) {
      _shineController.duration = Duration(
        milliseconds: _premiumShine ? 1700 : 3000,
      );
      _shineController.repeat();
    }
  }

  @override
  void dispose() {
    _shineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    final child = SizedBox(
      width: _totalWidth,
      height: _badgeSize,
      child: AnimatedBuilder(
        animation: _shineController,
        builder: (context, _) {
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              Positioned(
                left: _badgeSize * 0.48,
                child: _VipPillBody(
                  width: _pillWidth,
                  height: _height,
                  gradient: _pillGradient,
                  glowColor: _glowColor,
                  premiumShine: _premiumShine,
                  shineValue: _shineController.value,
                  size: widget.size,
                  child: _GoldenVipText(
                    label: 'VIP $_safeLevel',
                    fontSize: _fontSize,
                    premiumShine: _premiumShine,
                    shineValue: _shineController.value,
                    size: widget.size,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: _ShieldBadgeImage(
                  assetPath: _assetPath,
                  size: _badgeSize,
                  glowColor: _glowColor,
                  premiumShine: _premiumShine,
                  shineValue: _shineController.value,
                  fallbackGradient: _pillGradient,
                  level: _safeLevel,
                ),
              ),
            ],
          );
        },
      ),
    );

    if (widget.onTap == null) return child;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: widget.onTap,
        child: child,
      ),
    );
  }
}

class _VipPillBody extends StatelessWidget {
  const _VipPillBody({
    required this.width,
    required this.height,
    required this.gradient,
    required this.glowColor,
    required this.premiumShine,
    required this.shineValue,
    required this.size,
    required this.child,
  });

  final double width;
  final double height;
  final List<Color> gradient;
  final Color glowColor;
  final bool premiumShine;
  final double shineValue;
  final VipBadgeSize size;
  final Widget child;

  bool get _tiny => size == VipBadgeSize.tiny;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: _tiny ? 0.20 : premiumShine ? 0.55 : 0.28),
            blurRadius: _tiny ? 7 : premiumShine ? 18 : 11,
            spreadRadius: _tiny ? 0 : premiumShine ? 1.4 : 0.2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.42),
            blurRadius: _tiny ? 5 : 12,
            offset: Offset(0, _tiny ? 2 : 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradient,
                  stops: const [0.0, 0.35, 0.62, 1.0],
                ),
                border: Border.all(
                  color: const Color(0xFFFFD36A).withValues(alpha: _tiny ? 0.55 : 0.82),
                  width: _tiny ? 0.75 : 1.15,
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: _tiny ? 0.14 : 0.28),
                      Colors.white.withValues(alpha: 0.03),
                      Colors.black.withValues(alpha: _tiny ? 0.18 : 0.30),
                    ],
                    stops: const [0.0, 0.46, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              left: -width + (shineValue * width * 2.2),
              top: -height,
              bottom: -height,
              child: Transform.rotate(
                angle: -math.pi / 7,
                child: Container(
                  width: height * (_tiny ? 0.28 : premiumShine ? 0.76 : 0.46),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(
                          alpha: _tiny ? 0.18 : premiumShine ? 0.58 : 0.30,
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _ShieldBadgeImage extends StatelessWidget {
  const _ShieldBadgeImage({
    required this.assetPath,
    required this.size,
    required this.glowColor,
    required this.premiumShine,
    required this.shineValue,
    required this.fallbackGradient,
    required this.level,
  });

  final String assetPath;
  final double size;
  final Color glowColor;
  final bool premiumShine;
  final double shineValue;
  final List<Color> fallbackGradient;
  final int level;

  bool get _tiny => size <= 34;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size * 0.72,
            height: size * 0.72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(
                    alpha: _tiny ? 0.18 : premiumShine ? 0.72 : 0.34,
                  ),
                  blurRadius: _tiny ? 8 : premiumShine ? 25 : 15,
                  spreadRadius: _tiny ? 0 : premiumShine ? 2.5 : 0.4,
                ),
              ],
            ),
          ),
          Image.asset(
            assetPath,
            width: size,
            height: size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) => _FallbackShield(
              size: size,
              gradient: fallbackGradient,
              level: level,
            ),
          ),
          if (premiumShine)
            Positioned.fill(
              child: IgnorePointer(
                child: ClipOval(
                  child: Transform.translate(
                    offset: Offset((-size * 0.75) + (shineValue * size * 1.65), -size * 0.20),
                    child: Transform.rotate(
                      angle: -0.55,
                      child: Center(
                        child: Container(
                          width: _tiny ? size * 0.12 : size * 0.20,
                          height: size * 1.35,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.0),
                                Colors.white.withValues(alpha: _tiny ? 0.18 : 0.42),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (premiumShine && !_tiny) ...[
            Positioned(
              top: size * 0.08,
              right: size * 0.12,
              child: _Sparkle(
                size: size * 0.16,
                opacity: 0.52 + (math.sin(shineValue * math.pi * 2) * 0.24),
              ),
            ),
            Positioned(
              bottom: size * 0.10,
              left: size * 0.14,
              child: _Sparkle(
                size: size * 0.11,
                opacity: 0.34 + (math.cos(shineValue * math.pi * 2) * 0.18),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GoldenVipText extends StatelessWidget {
  const _GoldenVipText({
    required this.label,
    required this.fontSize,
    required this.premiumShine,
    required this.shineValue,
    required this.size,
  });

  final String label;
  final double fontSize;
  final bool premiumShine;
  final double shineValue;
  final VipBadgeSize size;

  bool get _tiny => size == VipBadgeSize.tiny;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: _tiny ? -0.20 : 0.35,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = _tiny ? 1.45 : premiumShine ? 2.5 : 2.0
              ..color = Colors.black.withValues(alpha: 0.68),
          ),
        ),
        ShaderMask(
          shaderCallback: (bounds) {
            return const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFF8C8),
                Color(0xFFFFC941),
                Color(0xFFFFF0A6),
                Color(0xFFD89418),
              ],
              stops: [0.0, 0.34, 0.58, 1.0],
            ).createShader(bounds);
          },
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: _tiny ? -0.20 : 0.35,
              shadows: [
                Shadow(
                  color: const Color(0xFFFFD766).withValues(
                    alpha: _tiny ? 0.42 : premiumShine ? 0.95 : 0.52,
                  ),
                  blurRadius: _tiny ? 4 : premiumShine ? 12 : 6,
                ),
                Shadow(
                  color: const Color(0xFF7A4300).withValues(alpha: 0.72),
                  blurRadius: _tiny ? 1.0 : 2.0,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRect(
              child: Align(
                alignment: Alignment(-1.35 + shineValue * 2.7, 0),
                child: Container(
                  width: _tiny ? 8 : premiumShine ? 24 : 15,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(
                          alpha: _tiny ? 0.26 : premiumShine ? 0.70 : 0.36,
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Icon(
        Icons.auto_awesome_rounded,
        color: const Color(0xFFFFE68D),
        size: size,
        shadows: [
          Shadow(
            color: const Color(0xFFFFD15C).withValues(alpha: 0.86),
            blurRadius: 10,
          ),
        ],
      ),
    );
  }
}

class _FallbackShield extends StatelessWidget {
  const _FallbackShield({
    required this.size,
    required this.gradient,
    required this.level,
  });

  final double size;
  final List<Color> gradient;
  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        border: Border.all(
          color: const Color(0xFFFFD36A).withValues(alpha: 0.85),
          width: size <= 34 ? 1.1 : 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient[2].withValues(alpha: 0.28),
            blurRadius: size <= 34 ? 7 : 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.shield_rounded,
          color: Colors.white.withValues(alpha: 0.88),
          size: size * 0.56,
        ),
      ),
    );
  }
}
