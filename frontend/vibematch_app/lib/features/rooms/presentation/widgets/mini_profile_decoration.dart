import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'room_avatar_frames.dart';
import 'room_theme.dart';

class MiniProfileDecoration extends StatelessWidget {
  const MiniProfileDecoration({
    super.key,
    required this.child,
    this.maxHeightFactor = 0.80,
    this.topRadius = 30,
    this.backgroundColor = Colors.white,
    this.showTopGlow = true,
  });

  final Widget child;
  final double maxHeightFactor;
  final double topRadius;
  final Color backgroundColor;
  final bool showTopGlow;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.vertical(top: Radius.circular(topRadius));

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * maxHeightFactor),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(borderRadius: borderRadius, child: const _MiniProfileCardSkin()),
          ),

          const Positioned(top: 0, left: 0, right: 0, child: MiniProfileHeaderDecoration()),
          child,
        ],
      ),
    );
  }
}

class MiniProfileAvatarDecoration extends StatelessWidget {
  const MiniProfileAvatarDecoration({
    super.key,
    required this.user,
    required this.onTap,
    this.size = 84,
    this.showHeartBadge = true,
    this.showOnlineRing = true,
  });

  final SeatUser user;
  final VoidCallback onTap;
  final double size;
  final bool showHeartBadge;
  final bool showOnlineRing;

  @override
  Widget build(BuildContext context) {
    final badgeSize = (size * 0.30).clamp(20.0, 30.0);

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          RoomAvatarFrameHost(
            frame: defaultStaticAvatarFrame,
            size: size,
            framePadding: 8,
            child: Container(
              width: size,
              height: size,
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: user.avatarColors)),
                child: Text(
                  avatarLetter(user.name),
                  style: TextStyle(color: Colors.white, fontSize: size * 0.35, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
          if (showOnlineRing)
            Positioned(
              right: size * 0.06,
              top: size * 0.08,
              child: Container(
                width: size * 0.13,
                height: size * 0.13,
                decoration: BoxDecoration(
                  color: const Color(0xFF21D07A),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [BoxShadow(color: const Color(0xFF21D07A).withValues(alpha: 0.50), blurRadius: 8)],
                ),
              ),
            ),
          if (showHeartBadge)
            Positioned(
              right: -2,
              bottom: size * 0.08,
              child: Container(
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [Color(0xFFFFC857), Color(0xFFFF5F7E)]),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [BoxShadow(color: RoomColors.coral.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Icon(Icons.favorite_rounded, color: Colors.white, size: badgeSize * 0.56),
              ),
            ),
        ],
      ),
    );
  }
}

class MiniProfileSectionCard extends StatelessWidget {
  const MiniProfileSectionCard({
    super.key,
    required this.child,
    this.onTap,
    this.backgroundColor = const Color(0xFFFCFAF6),
    this.borderColor = RoomColors.softLine,
    this.radius = 18,
    this.padding = const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color borderColor;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.025), blurRadius: 12, offset: const Offset(0, 5))],
      ),
      child: child,
    );

    if (onTap == null) return card;
    return InkWell(borderRadius: BorderRadius.circular(radius), onTap: onTap, child: card);
  }
}

class MiniProfilePill extends StatelessWidget {
  const MiniProfilePill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.onTap,
    this.filled = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? Colors.white : color;
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: filled ? 0.0 : 0.22)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: filled ? 0.20 : 0.08), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, color: foreground, size: 13), const SizedBox(width: 4)],
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: foreground, fontSize: 10.5, fontWeight: FontWeight.w900)),
        ],
      ),
    );

    if (onTap == null) return pill;
    return InkWell(borderRadius: BorderRadius.circular(999), onTap: onTap, child: pill);
  }
}

class MiniProfileCornerButton extends StatelessWidget {
  const MiniProfileCornerButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
    this.size = 36,
    this.iconSize = 19,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: size, height: size, child: Icon(icon, color: color, size: iconSize)),
      ),
    );
  }
}

class MiniProfileGradientGiftButton extends StatelessWidget {
  const MiniProfileGradientGiftButton({super.key, required this.onTap, this.label = 'SEND GIFT', this.height = 48});

  final VoidCallback onTap;
  final String label;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(colors: [Color(0xFFFFC107), Color(0xFFFF4F39)]),
        boxShadow: [BoxShadow(color: const Color(0xFFFF6A30).withValues(alpha: 0.22), blurRadius: 16, offset: const Offset(0, 7))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 19),
                const SizedBox(width: 7),
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniProfileCardSkin extends StatelessWidget {
  const _MiniProfileCardSkin();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Color(0xFFFFF7EC), Color(0xFFFDFBF7), Color(0xFFFFFFFF)],
          stops: const [0, 0.38, 1],
        ),
      ),
      child: Stack(
        children: const [
          Positioned(top: 12, left: -44, child: _MiniProfileSoftOrb(color: Color(0xFFFFC857))),
          Positioned(top: 38, right: -52, child: _MiniProfileSoftOrb(color: Color(0xFF18C7B7))),
          Positioned(top: 0, left: 0, right: 0, child: _MiniProfileTopSheen()),
        ],
      ),
    );
  }
}

class MiniProfileHeaderDecoration extends StatelessWidget {
  const MiniProfileHeaderDecoration({super.key});

  static const String _bannerAsset =
      'assets/images/mini_profile_decorations/purple_gold_banner.png';

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    return IgnorePointer(
      child: SizedBox(
        height: 56,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -34,
              child: SizedBox(
                width: screenWidth + 112,
                height: 90,
                child: Image.asset(
                  _bannerAsset,
                  width: screenWidth + 112,
                  height: 90,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const _FallbackMiniProfileHeaderDecoration(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FallbackMiniProfileHeaderDecoration extends StatelessWidget {
  const _FallbackMiniProfileHeaderDecoration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 17,
            left: 34,
            right: 34,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  colors: [Colors.transparent, RoomColors.gold.withValues(alpha: 0.24), RoomColors.coral.withValues(alpha: 0.12), Colors.transparent],
                ),
              ),
            ),
          ),
          const Positioned(top: 16, left: 42, child: _MiniProfileWing(isLeft: true)),
          const Positioned(top: 16, right: 42, child: _MiniProfileWing(isLeft: false)),
        ],
      ),
    );
  }
}


class _MiniProfileWing extends StatelessWidget {
  const _MiniProfileWing({required this.isLeft});

  final bool isLeft;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scaleX: isLeft ? 1 : -1,
      child: CustomPaint(size: const Size(64, 24), painter: _MiniProfileWingPainter()),
    );
  }
}

class _MiniProfileWingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(colors: [Color(0x00FFC857), Color(0x99FFC857), Color(0x33FF5F7E)]).createShader(Offset.zero & size);

    final path = Path()
      ..moveTo(size.width, size.height * 0.52)
      ..cubicTo(size.width * 0.72, size.height * 0.05, size.width * 0.34, size.height * 0.22, 0, size.height * 0.60);
    canvas.drawPath(path, paint);

    for (var i = 0; i < 3; i++) {
      final y = size.height * (0.44 + (i * 0.18));
      final p = Path()
        ..moveTo(size.width * (0.88 - i * 0.10), y)
        ..cubicTo(size.width * 0.62, y - 8, size.width * 0.36, y - 2, size.width * 0.12, y + 5);
      canvas.drawPath(p, paint..strokeWidth = 0.85);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MiniProfileSoftOrb extends StatelessWidget {
  const _MiniProfileSoftOrb({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 130,
        height: 130,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color.withValues(alpha: 0.10), color.withValues(alpha: 0.035), Colors.transparent]),
        ),
      ),
    );
  }
}

class _MiniProfileTopSheen extends StatelessWidget {
  const _MiniProfileTopSheen();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: 86,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white.withValues(alpha: 0.36), Colors.white.withValues(alpha: 0.10), Colors.white.withValues(alpha: 0.0)],
          ),
        ),
      ),
    );
  }
}

