import 'package:flutter/material.dart';

class MiniProfileFamilyBadge extends StatelessWidget {
  const MiniProfileFamilyBadge({
    super.key,
    required this.familyName,
    required this.familyLevel,
    required this.onTap,
    this.height = 24,
    this.minWidth = 66,
    this.maxWidth = 132,
  });

  final String familyName;
  final String familyLevel;
  final VoidCallback onTap;
  final double height;
  final double minWidth;
  final double maxWidth;

  String get _familyName {
    final clean = familyName.trim();
    if (clean.isEmpty) return 'Family';
    return clean;
  }

  String get _level {
    final raw = familyLevel.trim().toLowerCase();
    if (raw.contains('platinum')) return 'platinum';
    if (raw.contains('gold')) return 'gold';
    if (raw.contains('silver')) return 'silver';
    return 'bronze';
  }

  _FamilyBadgeStyle get _style {
    switch (_level) {
      case 'platinum':
        return const _FamilyBadgeStyle(
          assetPath: 'assets/images/family_badges/platinum.png',
          top: Color(0xFF7B8594),
          bottom: Color(0xFF4A5463),
          border: Color(0xFFEAF0F8),
          text: Color(0xFFFFFFFF),
          shine: Color(0xFFFFFFFF),
          glow: Color(0xFFDDE6F3),
          shineAlpha: 0.56,
          glowAlpha: 0.24,
          durationMs: 1050,
        );
      case 'gold':
        return const _FamilyBadgeStyle(
          assetPath: 'assets/images/family_badges/gold.png',
          top: Color(0xFFE0B12F),
          bottom: Color(0xFF8D6508),
          border: Color(0xFFFFE28A),
          text: Color(0xFFFFF8DB),
          shine: Color(0xFFFFF2B0),
          glow: Color(0xFFFFD96A),
          shineAlpha: 0.40,
          glowAlpha: 0.18,
          durationMs: 1380,
        );
      case 'silver':
        return const _FamilyBadgeStyle(
          assetPath: 'assets/images/family_badges/silver.png',
          top: Color(0xFFD5DAE1),
          bottom: Color(0xFF87919C),
          border: Color(0xFFF0F4F8),
          text: Color(0xFFFBFDFF),
          shine: Color(0xFFFFFFFF),
          glow: Color(0xFFD6DDE5),
          shineAlpha: 0.28,
          glowAlpha: 0.12,
          durationMs: 1720,
        );
      default:
        return const _FamilyBadgeStyle(
          assetPath: 'assets/images/family_badges/bronze.png',
          top: Color(0xFFC08A5A),
          bottom: Color(0xFF7A4E2D),
          border: Color(0xFFDCA477),
          text: Color(0xFFFFE8D5),
          shine: Color(0xFFFFD8BA),
          glow: Color(0xFFC68E61),
          shineAlpha: 0.16,
          glowAlpha: 0.08,
          durationMs: 2100,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;
    final badgeSize = height + 2;
    final pillHeight = height - 4;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: IntrinsicWidth(
          child: SizedBox(
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: ClipPath(
                    clipper: const _FamilyBadgeClipper(),
                    child: Container(
                      constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
                      height: pillHeight,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [style.top, style.bottom],
                        ),
                        border: Border.all(
                          color: style.border.withValues(alpha: 0.86),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: style.glow.withValues(alpha: style.glowAlpha),
                            blurRadius: _level == 'platinum' ? 12 : 7,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: 16,
                            right: 8,
                            top: 2,
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: Colors.white.withValues(
                                  alpha: _level == 'platinum' ? 0.22 : 0.12,
                                ),
                              ),
                            ),
                          ),
                          _FamilyBadgeShine(style: style),
                          Padding(
                            padding: const EdgeInsets.only(left: 24, right: 13),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _familyName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: style.text,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                  letterSpacing: -0.08,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: -3.5,
                  child: Image.asset(
                    style.assetPath,
                    width: badgeSize,
                    height: badgeSize,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: badgeSize,
                        height: badgeSize,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: style.top,
                          border: Border.all(color: style.border, width: 0.8),
                        ),
                        child: Text(
                          _familyName.characters.first.toUpperCase(),
                          style: TextStyle(
                            color: style.text,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FamilyBadgeStyle {
  const _FamilyBadgeStyle({
    required this.assetPath,
    required this.top,
    required this.bottom,
    required this.border,
    required this.text,
    required this.shine,
    required this.glow,
    required this.shineAlpha,
    required this.glowAlpha,
    required this.durationMs,
  });

  final String assetPath;
  final Color top;
  final Color bottom;
  final Color border;
  final Color text;
  final Color shine;
  final Color glow;
  final double shineAlpha;
  final double glowAlpha;
  final int durationMs;
}

class _FamilyBadgeShine extends StatefulWidget {
  const _FamilyBadgeShine({required this.style});

  final _FamilyBadgeStyle style;

  @override
  State<_FamilyBadgeShine> createState() => _FamilyBadgeShineState();
}

class _FamilyBadgeShineState extends State<_FamilyBadgeShine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.style.durationMs),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant _FamilyBadgeShine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.style.durationMs != widget.style.durationMs) {
      _controller.duration = Duration(milliseconds: widget.style.durationMs);
      _controller
        ..reset()
        ..repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final x = -0.85 + (_controller.value * 2.0);
        return Positioned.fill(
          child: IgnorePointer(
            child: Transform.translate(
              offset: Offset(x * 105, 0),
              child: Transform.rotate(
                angle: -0.45,
                child: Center(
                  child: Container(
                    width: 14,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.style.shine.withValues(alpha: 0.0),
                          widget.style.shine.withValues(alpha: widget.style.shineAlpha * 0.45),
                          widget.style.shine.withValues(alpha: widget.style.shineAlpha),
                          widget.style.shine.withValues(alpha: widget.style.shineAlpha * 0.45),
                          widget.style.shine.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FamilyBadgeClipper extends CustomClipper<Path> {
  const _FamilyBadgeClipper();

  @override
  Path getClip(Size size) {
    const rightCut = 9.0;
    final radius = size.height / 2;
    final path = Path()
      ..moveTo(radius, 0)
      ..lineTo(size.width - rightCut, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width - rightCut, size.height)
      ..lineTo(radius, size.height)
      ..arcToPoint(
        Offset(radius, 0),
        radius: Radius.circular(radius),
        clockwise: true,
      )
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
