import 'package:flutter/material.dart';

import '../../data/mini_profile_economy_service.dart';
import '../live_room_models.dart';
import 'experience/experience_level_models.dart';
import 'vip_badge.dart';

class MiniProfileLevelRow extends StatelessWidget {
  const MiniProfileLevelRow({
    super.key,
    required this.user,
    required this.onVipTap,
    required this.onSvipTap,
    required this.onSendingLevelTap,
    required this.onReceivingLevelTap,
  });

  final SeatUser user;
  final VoidCallback onVipTap;
  final VoidCallback onSvipTap;
  final VoidCallback onSendingLevelTap;
  final VoidCallback onReceivingLevelTap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MiniProfileEconomySummary>(
      future: MiniProfileEconomyService.instance.summaryForSeatUser(user),
      builder: (context, snapshot) {
        final data =
            snapshot.data ?? MiniProfileEconomySummary.fromSeatUser(user);
        final sentStyle = data.sentLevel > 0
            ? experiencePillStyleFor(
                type: ExperienceLevelType.sent,
                level: data.sentLevel,
              )
            : null;
        final receivedStyle = data.receiveLevel > 0
            ? experiencePillStyleFor(
                type: ExperienceLevelType.received,
                level: data.receiveLevel,
              )
            : null;

        final items = <Widget>[
          if (data.vipLevel > 0)
            VipBadge(
              level: data.vipLevel,
              size: VipBadgeSize.small,
              onTap: onVipTap,
            ),
          if (data.svipLevel > 0)
            SvipBadge(
              level: data.svipLevel,
              size: VipBadgeSize.tiny,
              onTap: onSvipTap,
            ),
          if (sentStyle != null)
            MiniProfileCleanLevelPill(
              label: 'LV ${data.sentLevel}',
              icon: sentStyle.crownIcon,
              width: 56,
              background: sentStyle.gradient.first,
              gradientColors: sentStyle.gradient,
              border: sentStyle.glowColor,
              textColor: sentStyle.textColor,
              shineColor: sentStyle.crownColor,
              active: true,
              onTap: onSendingLevelTap,
            ),
          if (receivedStyle != null)
            MiniProfileCleanLevelPill(
              label: 'LV ${data.receiveLevel}',
              icon: receivedStyle.crownIcon,
              width: 56,
              background: receivedStyle.gradient.first,
              gradientColors: receivedStyle.gradient,
              border: receivedStyle.glowColor,
              textColor: receivedStyle.textColor,
              shineColor: receivedStyle.crownColor,
              active: true,
              onTap: onReceivingLevelTap,
            ),
        ];

        if (items.isEmpty) return const SizedBox.shrink();

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i != 0) const SizedBox(width: 6),
              items[i],
            ],
          ],
        );
      },
    );
  }
}

class MiniProfileCleanLevelPill extends StatelessWidget {
  const MiniProfileCleanLevelPill({
    super.key,
    required this.label,
    required this.icon,
    required this.width,
    required this.background,
    required this.border,
    required this.textColor,
    required this.onTap,
    required this.shineColor,
    this.gradientColors,
    this.active = true,
  });

  final String label;
  final IconData icon;
  final double width;
  final Color background;
  final List<Color>? gradientColors;
  final Color border;
  final Color textColor;
  final VoidCallback onTap;
  final Color shineColor;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final effectiveBackground = active ? background : const Color(0xFFE6E1E8);
    final effectiveBorder = active ? border : const Color(0xFFC7BEC9);
    final effectiveTextColor = active ? textColor : const Color(0xFF8D8392);
    final effectiveGradient = active ? gradientColors : null;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: width,
        height: 26,
        decoration: BoxDecoration(
          color: effectiveGradient == null ? effectiveBackground : null,
          gradient: effectiveGradient == null
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: effectiveGradient,
                ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: effectiveBorder.withValues(alpha: active ? 0.72 : 0.65),
            width: 0.8,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: effectiveBorder.withValues(alpha: 0.16),
                    blurRadius: 9,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 8,
                right: 8,
                top: 3,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Colors.white.withValues(alpha: active ? 0.28 : 0.22),
                  ),
                ),
              ),
              if (active) MiniProfilePillShine(color: shineColor),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: effectiveTextColor, size: 11.5),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: effectiveTextColor,
                        fontSize: 10.2,
                        fontWeight: FontWeight.w900,
                        shadows: active && effectiveGradient != null
                            ? [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.22),
                                  blurRadius: 3,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MiniProfilePillShine extends StatefulWidget {
  const MiniProfilePillShine({super.key, required this.color});

  final Color color;

  @override
  State<MiniProfilePillShine> createState() => _MiniProfilePillShineState();
}

class _MiniProfilePillShineState extends State<MiniProfilePillShine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1850),
    )..repeat();
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
        final x = -0.65 + (_controller.value * 1.65);
        return Positioned.fill(
          child: Transform.translate(
            offset: Offset(x * 82, 0),
            child: Transform.rotate(
              angle: -0.42,
              child: Center(
                child: Container(
                  width: 13,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.color.withValues(alpha: 0.0),
                        widget.color.withValues(alpha: 0.28),
                        Colors.white.withValues(alpha: 0.40),
                        widget.color.withValues(alpha: 0.18),
                        widget.color.withValues(alpha: 0.0),
                      ],
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
