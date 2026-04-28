import 'package:flutter/material.dart';

import 'room_theme.dart';

enum VipBadgeSize { tiny, small, medium, large }

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

  int get _safeLevel => widget.level.clamp(0, 50);
  bool get _visible => widget.level > 0 || widget.showWhenZero;
  bool get _isChatSize => widget.size == VipBadgeSize.tiny;
  bool get _premiumShine => _safeLevel >= 30 && !_isChatSize;
  bool get _basicShine => !_premiumShine;

  @override
  void initState() {
    super.initState();
    _shineController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _premiumShine ? 1700 : 3800),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant VipBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPremium = oldWidget.level >= 30 && oldWidget.size != VipBadgeSize.tiny;
    if (oldPremium != _premiumShine || oldWidget.size != widget.size) {
      _shineController.duration = Duration(
        milliseconds: _premiumShine ? 1700 : 3800,
      );
      _shineController.repeat();
    }
  }

  @override
  void dispose() {
    _shineController.dispose();
    super.dispose();
  }

  String get _assetPath {
    final value = _safeLevel;
    if (value <= 10) return '$_assetBase/vip_emerald_1_10.png';
    if (value <= 20) return '$_assetBase/vip_purple_11_20.png';
    if (value <= 30) return '$_assetBase/vip_crimson_21_30.png';
    if (value <= 40) return '$_assetBase/vip_diamond_31_40.png';
    return '$_assetBase/vip_mythic_41_50.png';
  }

  Color get _fallbackStart {
    final value = _safeLevel;
    if (value <= 10) return const Color(0xFF009B56);
    if (value <= 20) return const Color(0xFF5B16B8);
    if (value <= 30) return const Color(0xFFC30022);
    if (value <= 40) return const Color(0xFF006FEA);
    return const Color(0xFF080808);
  }

  Color get _fallbackEnd {
    final value = _safeLevel;
    if (value <= 10) return const Color(0xFF00E676);
    if (value <= 20) return const Color(0xFFB347FF);
    if (value <= 30) return const Color(0xFFFF1744);
    if (value <= 40) return const Color(0xFF00B0FF);
    return const Color(0xFFFFC857);
  }

  double get _width => switch (widget.size) {
        VipBadgeSize.tiny => 50,
        VipBadgeSize.small => 62,
        VipBadgeSize.medium => 82,
        VipBadgeSize.large => 112,
      };

  double get _height => switch (widget.size) {
        VipBadgeSize.tiny => 22,
        VipBadgeSize.small => 28,
        VipBadgeSize.medium => 38,
        VipBadgeSize.large => 52,
      };

  double get _fontSize => switch (widget.size) {
        VipBadgeSize.tiny => 8.5,
        VipBadgeSize.small => 10,
        VipBadgeSize.medium => 13,
        VipBadgeSize.large => 17,
      };

  EdgeInsets get _textPadding => switch (widget.size) {
        VipBadgeSize.tiny => const EdgeInsets.only(top: 2),
        VipBadgeSize.small => const EdgeInsets.only(top: 3),
        VipBadgeSize.medium => const EdgeInsets.only(top: 4),
        VipBadgeSize.large => const EdgeInsets.only(top: 6),
      };

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    final child = SizedBox(
      width: _width,
      height: _height,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          Image.asset(
            _assetPath,
            fit: BoxFit.fill,
            errorBuilder: (context, error, stackTrace) => _FallbackBadge(
              start: _fallbackStart,
              end: _fallbackEnd,
            ),
          ),
          _StaticGlass(
            width: _width,
            height: _height,
            premium: _premiumShine,
            chatSize: _isChatSize,
          ),
          _MovingGlassShine(
            animation: _shineController,
            width: _width,
            height: _height,
            premium: _premiumShine,
            chatSize: _isChatSize,
          ),
          if (_premiumShine)
            _SecondMovingGlassShine(
              animation: _shineController,
              width: _width,
              height: _height,
            ),
          Padding(
            padding: _textPadding,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _GoldVipText(
                  label: 'VIP $_safeLevel',
                  fontSize: _fontSize,
                  premium: _premiumShine,
                  chatSize: _isChatSize,
                ),
              ),
            ),
          ),
        ],
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

class _GoldVipText extends StatelessWidget {
  const _GoldVipText({
    required this.label,
    required this.fontSize,
    required this.premium,
    required this.chatSize,
  });

  final String label;
  final double fontSize;
  final bool premium;
  final bool chatSize;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.05,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = chatSize ? 1.55 : premium ? 2.45 : 2.05
              ..color = const Color(0xFF5F3300),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFFFFE8A3),
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.05,
            shadows: [
              Shadow(
                color: const Color(0xFFFFD56A),
                blurRadius: chatSize ? 5 : premium ? 14 : 8,
                offset: const Offset(0, 0.8),
              ),
              Shadow(
                color: const Color(0xFF8A5200),
                blurRadius: chatSize ? 1.2 : premium ? 4 : 2,
                offset: const Offset(0, 1.1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StaticGlass extends StatelessWidget {
  const _StaticGlass({
    required this.width,
    required this.height,
    required this.premium,
    required this.chatSize,
  });

  final double width;
  final double height;
  final bool premium;
  final bool chatSize;

  @override
  Widget build(BuildContext context) {
    final highlightAlpha = chatSize ? 0.16 : premium ? 0.42 : 0.26;
    final dotAlpha = chatSize ? 0.0 : premium ? 0.22 : 0.10;

    return Stack(
      children: [
        Positioned(
          top: height * 0.11,
          left: width * 0.14,
          right: width * 0.14,
          child: IgnorePointer(
            child: Container(
              height: height * (chatSize ? 0.12 : premium ? 0.24 : 0.18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: highlightAlpha),
                    Colors.white.withValues(alpha: chatSize ? 0.04 : premium ? 0.18 : 0.10),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (!chatSize)
          Positioned(
            left: width * 0.18,
            top: height * 0.20,
            child: IgnorePointer(
              child: Container(
                width: width * (premium ? 0.20 : 0.13),
                height: height * (premium ? 0.22 : 0.14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: dotAlpha),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MovingGlassShine extends StatelessWidget {
  const _MovingGlassShine({
    required this.animation,
    required this.width,
    required this.height,
    required this.premium,
    required this.chatSize,
  });

  final Animation<double> animation;
  final double width;
  final double height;
  final bool premium;
  final bool chatSize;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final travel = width * (chatSize ? 1.45 : premium ? 1.95 : 1.62) * animation.value;
              return Stack(
                children: [
                  Transform.translate(
                    offset: Offset(-width * 0.78 + travel, -height * 0.70),
                    child: Transform.rotate(
                      angle: -0.34,
                      child: Container(
                        width: width * (chatSize ? 0.11 : premium ? 0.34 : 0.18),
                        height: height * (chatSize ? 2.0 : 2.7),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.0),
                              Colors.white.withValues(alpha: chatSize ? 0.02 : premium ? 0.12 : 0.04),
                              Colors.white.withValues(alpha: chatSize ? 0.06 : premium ? 0.34 : 0.12),
                              Colors.white.withValues(alpha: chatSize ? 0.12 : premium ? 0.62 : 0.24),
                              Colors.white.withValues(alpha: chatSize ? 0.06 : premium ? 0.34 : 0.12),
                              Colors.white.withValues(alpha: chatSize ? 0.02 : premium ? 0.12 : 0.04),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SecondMovingGlassShine extends StatelessWidget {
  const _SecondMovingGlassShine({
    required this.animation,
    required this.width,
    required this.height,
  });

  final Animation<double> animation;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final shiftedValue = (animation.value + 0.42) % 1.0;
              final travel = width * 1.75 * shiftedValue;
              return Transform.translate(
                offset: Offset(-width * 0.84 + travel, -height * 0.55),
                child: Transform.rotate(
                  angle: -0.34,
                  child: Container(
                    width: width * 0.14,
                    height: height * 2.25,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white.withValues(alpha: 0.16),
                          Colors.white.withValues(alpha: 0.38),
                          Colors.white.withValues(alpha: 0.16),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FallbackBadge extends StatelessWidget {
  const _FallbackBadge({required this.start, required this.end});

  final Color start;
  final Color end;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(colors: [start, end]),
        border: Border.all(color: RoomColors.gold, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: end.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );
  }
}
