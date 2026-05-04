import 'package:flutter/material.dart';

import '../live_room_models.dart';

class MiniProfileLevelRow extends StatelessWidget {
  const MiniProfileLevelRow({
    super.key,
    required this.user,
    required this.onVipTap,
    required this.onSendingLevelTap,
    required this.onReceivingLevelTap,
  });

  final SeatUser user;
  final VoidCallback onVipTap;
  final VoidCallback onSendingLevelTap;
  final VoidCallback onReceivingLevelTap;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      if (user.svipLevel > 0)
        MiniProfileCleanLevelPill(
          label: 'SVIP ${user.svipLevel}',
          icon: Icons.diamond_rounded,
          width: 76,
          background: const Color(0xFF30220B),
          border: const Color(0xFFD7AA45),
          textColor: const Color(0xFFFFE2A1),
          shineColor: const Color(0xFFFFF1B8),
          active: true,
          onTap: onVipTap,
        ),
      MiniProfileCleanLevelPill(
        label: 'Lv ${user.sendingLevel}',
        icon: Icons.emoji_events_rounded,
        width: 68,
        background: const Color(0xFFEFF3FF),
        border: const Color(0xFF91A9E8),
        textColor: const Color(0xFF465B9D),
        shineColor: Colors.white,
        active: user.sendingLevel > 0,
        onTap: onSendingLevelTap,
      ),
      MiniProfileCleanLevelPill(
        label: 'Lv ${user.receivingLevel}',
        icon: Icons.favorite_rounded,
        width: 68,
        background: const Color(0xFFFFDCEB),
        border: const Color(0xFFE26A98),
        textColor: const Color(0xFF661C3B),
        shineColor: const Color(0xFFFFF0F7),
        active: user.receivingLevel > 0,
        onTap: onReceivingLevelTap,
      ),
    ];

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
    this.active = true,
  });

  final String label;
  final IconData icon;
  final double width;
  final Color background;
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

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: width,
        height: 26,
        decoration: BoxDecoration(
          color: effectiveBackground,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: effectiveBorder.withValues(alpha: active ? 0.72 : 0.65),
            width: 0.8,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: effectiveBorder.withValues(alpha: 0.12),
                    blurRadius: 8,
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
