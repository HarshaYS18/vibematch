import 'package:flutter/material.dart';

import 'vip_badge.dart';

class ChatVipBadge extends StatelessWidget {
  const ChatVipBadge({
    super.key,
    required this.level,
    this.onTap,
    this.showWhenZero = true,
  });

  final int level;
  final VoidCallback? onTap;
  final bool showWhenZero;

  @override
  Widget build(BuildContext context) {
    return VipBadge(
      level: level,
      size: VipBadgeSize.tiny,
      showWhenZero: showWhenZero,
      onTap: onTap,
    );
  }
}
