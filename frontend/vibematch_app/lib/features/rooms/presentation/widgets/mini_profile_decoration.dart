import 'package:flutter/material.dart';

import '../live_room_models.dart';
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
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * maxHeightFactor,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(topRadius)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 28,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(topRadius)),
        child: Stack(
          children: [
            if (showTopGlow)
              const Positioned(
                top: -90,
                left: -60,
                right: -60,
                child: _MiniProfileTopGlow(),
              ),
            child,
          ],
        ),
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
    final frameSize = size + 14;
    final innerSize = size;
    final badgeSize = (size * 0.30).clamp(20.0, 30.0);

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: frameSize,
            height: frameSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  RoomColors.gold,
                  user.avatarColors.first,
                  RoomColors.coral,
                  RoomColors.aqua,
                  RoomColors.gold,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: user.avatarColors.first.withValues(alpha: 0.30),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: RoomColors.gold.withValues(alpha: 0.18),
                  blurRadius: 34,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
          ),
          Container(
            width: innerSize,
            height: innerSize,
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: user.avatarColors),
              ),
              child: Text(
                avatarLetter(user.name),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.35,
                  fontWeight: FontWeight.w900,
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
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF21D07A).withValues(alpha: 0.50),
                      blurRadius: 8,
                    ),
                  ],
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
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFC857), Color(0xFFFF5F7E)],
                  ),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: RoomColors.coral.withValues(alpha: 0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  color: Colors.white,
                  size: badgeSize * 0.56,
                ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return card;

    return InkWell(
      borderRadius: BorderRadius.circular(radius),
      onTap: onTap,
      child: card,
    );
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
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: filled ? 0.20 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: foreground, size: 13),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return pill;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: pill,
    );
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
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: color, size: iconSize),
        ),
      ),
    );
  }
}

class MiniProfileGradientGiftButton extends StatelessWidget {
  const MiniProfileGradientGiftButton({
    super.key,
    required this.onTap,
    this.label = 'SEND GIFT',
    this.height = 48,
  });

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
        gradient: const LinearGradient(
          colors: [Color(0xFFFFC107), Color(0xFFFF4F39)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6A30).withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
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
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
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

class _MiniProfileTopGlow extends StatelessWidget {
  const _MiniProfileTopGlow();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              RoomColors.aqua.withValues(alpha: 0.16),
              RoomColors.violet.withValues(alpha: 0.08),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}
