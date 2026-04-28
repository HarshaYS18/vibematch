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

  // VIP 0 is intentionally visible now. It uses the silver badge.
  bool get _visible => widget.level >= 0 || widget.showWhenZero;

  bool get _isChatBadge => widget.size == VipBadgeSize.tiny;
  bool get _premiumShine => _safeLevel >= 30;

  _VipBadgeTier get _tier {
    final value = _safeLevel;

    if (value >= 41) return _VipBadgeTier.purple;
    if (value >= 30) return _VipBadgeTier.green;
    if (value >= 21) return _VipBadgeTier.blue;
    if (value >= 11) return _VipBadgeTier.red;
    if (value >= 6) return _VipBadgeTier.blackGold;

    // VIP 0, frozen VIP, and VIP 1-5 use the silver family.
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

  double get _chatBadgeSize => 20;
  double get _chatPillWidth => 28;
  double get _chatPillHeight => 12;
  double get _chatTotalWidth => _chatPillWidth + (_chatBadgeSize * 0.52);

  double get _iconTextHeight {
    return switch (widget.size) {
      VipBadgeSize.tiny => _chatBadgeSize,
      VipBadgeSize.small => 28,
      VipBadgeSize.medium => 38,
      VipBadgeSize.large => 52,
    };
  }

  double get _iconTextWidth {
    return switch (widget.size) {
      VipBadgeSize.tiny => _chatTotalWidth,
      VipBadgeSize.small => 72,
      VipBadgeSize.medium => 94,
      VipBadgeSize.large => 126,
    };
  }

  double get _iconSize {
    return switch (widget.size) {
      VipBadgeSize.tiny => _chatBadgeSize,
      VipBadgeSize.small => 24,
      VipBadgeSize.medium => 34,
      VipBadgeSize.large => 46,
    };
  }

  double get _fontSize {
    return switch (widget.size) {
      VipBadgeSize.tiny => 6.2,
      VipBadgeSize.small => 10.8,
      VipBadgeSize.medium => 14.2,
      VipBadgeSize.large => 18.8,
    };
  }

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

    final child = _isChatBadge ? _buildChatPillBadge() : _buildMiniProfileIconBadge();

    if (widget.onTap == null) return child;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(_isChatBadge ? 3 : 999),
      child: InkWell(
        borderRadius: BorderRadius.circular(_isChatBadge ? 3 : 999),
        onTap: widget.onTap,
        child: child,
      ),
    );
  }

  Widget _buildChatPillBadge() {
    return SizedBox(
      width: _chatTotalWidth,
      height: _chatBadgeSize,
      child: AnimatedBuilder(
        animation: _shineController,
        builder: (context, _) {
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              Positioned(
                left: _chatBadgeSize * 0.47,
                child: _VipPillBody(
                  width: _chatPillWidth,
                  height: _chatPillHeight,
                  gradient: _pillGradient,
                  glowColor: _glowColor,
                  premiumShine: _premiumShine,
                  shineValue: _shineController.value,
                  sharpCorners: true,
                  child: _GoldenVipText(
                    label: 'VIP $_safeLevel',
                    fontSize: _fontSize,
                    premiumShine: _premiumShine,
                    shineValue: _shineController.value,
                    compact: true,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: _ShieldBadgeImage(
                  assetPath: _assetPath,
                  size: _chatBadgeSize,
                  glowColor: _glowColor,
                  premiumShine: _premiumShine,
                  shineValue: _shineController.value,
                  fallbackGradient: _pillGradient,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMiniProfileIconBadge() {
    return SizedBox(
      width: _iconTextWidth,
      height: _iconTextHeight,
      child: AnimatedBuilder(
        animation: _shineController,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ShieldBadgeImage(
                assetPath: _assetPath,
                size: _iconSize,
                glowColor: _glowColor,
                premiumShine: _premiumShine,
                shineValue: _shineController.value,
                fallbackGradient: _pillGradient,
              ),
              SizedBox(width: widget.size == VipBadgeSize.small ? 4 : 6),
              Flexible(
                child: _GoldenVipText(
                  label: 'VIP $_safeLevel',
                  fontSize: _fontSize,
                  premiumShine: _premiumShine,
                  shineValue: _shineController.value,
                  compact: false,
                ),
              ),
            ],
          );
        },
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
    required this.sharpCorners,
    required this.child,
  });

  final double width;
  final double height;
  final List<Color> gradient;
  final Color glowColor;
  final bool premiumShine;
  final double shineValue;
  final bool sharpCorners;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(sharpCorners ? 2.5 : height);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: premiumShine ? 0.36 : 0.16),
            blurRadius: premiumShine ? 9 : 5,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.42),
            blurRadius: 5,
            offset: const Offset(0, 2),
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
                  color: const Color(0xFFFFD36A).withValues(alpha: 0.52),
                  width: 0.55,
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
                      Colors.white.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0.02),
                      Colors.black.withValues(alpha: 0.18),
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
                  width: height * (premiumShine ? 0.56 : 0.32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: premiumShine ? 0.42 : 0.22),
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
  });

  final String assetPath;
  final double size;
  final Color glowColor;
  final bool premiumShine;
  final double shineValue;
  final List<Color> fallbackGradient;

  bool get _compact => size <= 22;

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
            width: size * 0.68,
            height: size * 0.68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(
                    alpha: _compact ? 0.16 : premiumShine ? 0.70 : 0.32,
                  ),
                  blurRadius: _compact ? 5 : premiumShine ? 22 : 12,
                  spreadRadius: _compact ? 0 : premiumShine ? 2 : 0.3,
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
                          width: _compact ? size * 0.10 : size * 0.18,
                          height: size * 1.25,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.0),
                                Colors.white.withValues(alpha: _compact ? 0.14 : 0.40),
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
          if (premiumShine && !_compact) ...[
            Positioned(
              top: size * 0.08,
              right: size * 0.12,
              child: _Sparkle(
                size: size * 0.14,
                opacity: 0.50 + (math.sin(shineValue * math.pi * 2) * 0.22),
              ),
            ),
            Positioned(
              bottom: size * 0.10,
              left: size * 0.14,
              child: _Sparkle(
                size: size * 0.10,
                opacity: 0.32 + (math.cos(shineValue * math.pi * 2) * 0.16),
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
    required this.compact,
  });

  final String label;
  final double fontSize;
  final bool premiumShine;
  final double shineValue;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.visible,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: compact ? -0.50 : 0.25,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = compact ? 1.0 : premiumShine ? 2.4 : 1.9
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
            overflow: TextOverflow.visible,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: compact ? -0.50 : 0.25,
              shadows: [
                Shadow(
                  color: const Color(0xFFFFD766).withValues(
                    alpha: compact ? 0.34 : premiumShine ? 0.94 : 0.52,
                  ),
                  blurRadius: compact ? 3 : premiumShine ? 11 : 6,
                ),
                Shadow(
                  color: const Color(0xFF7A4300).withValues(alpha: 0.70),
                  blurRadius: compact ? 0.8 : 1.7,
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
                  width: compact ? 6 : premiumShine ? 22 : 14,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(
                          alpha: compact ? 0.20 : premiumShine ? 0.68 : 0.34,
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
  });

  final double size;
  final List<Color> gradient;

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
          width: size <= 22 ? 0.8 : 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient[2].withValues(alpha: 0.26),
            blurRadius: size <= 22 ? 5 : 12,
            offset: const Offset(0, 3),
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
