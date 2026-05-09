import 'package:flutter/material.dart';

import '../../../../auth/models/role_badge.dart';

class OfficialRoleBadgePill extends StatelessWidget {
  const OfficialRoleBadgePill({
    super.key,
    required this.badge,
    this.compact = false,
  });

  final RoleBadge badge;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 22 : 28,
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 10, vertical: 0),
      decoration: BoxDecoration(
        color: badge.backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: badge.borderColor.withValues(alpha: 0.82), width: 1),
        boxShadow: [
          BoxShadow(
            color: badge.borderColor.withValues(alpha: compact ? 0.12 : 0.20),
            blurRadius: compact ? 8 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badge.iconData, color: badge.textColor, size: compact ? 11 : 14),
          SizedBox(width: compact ? 4 : 6),
          Flexible(
            child: Text(
              compact ? badge.badgeLabel : badge.pillLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: badge.textColor,
                fontSize: compact ? 9.5 : 11.5,
                fontWeight: FontWeight.w900,
                letterSpacing: compact ? -0.1 : 0.05,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
