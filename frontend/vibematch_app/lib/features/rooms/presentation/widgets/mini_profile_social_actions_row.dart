import 'package:flutter/material.dart';

import 'room_theme.dart';

enum MiniProfileSocialRelation {
  follow,
  following,
  followBack,
  friends,
}

extension MiniProfileSocialRelationX on MiniProfileSocialRelation {
  String get label {
    switch (this) {
      case MiniProfileSocialRelation.follow:
        return 'Follow';
      case MiniProfileSocialRelation.following:
        return 'Following';
      case MiniProfileSocialRelation.followBack:
        return 'Follow back';
      case MiniProfileSocialRelation.friends:
        return 'Friends';
    }
  }

  IconData get icon {
    switch (this) {
      case MiniProfileSocialRelation.follow:
        return Icons.person_add_alt_1_rounded;
      case MiniProfileSocialRelation.following:
        return Icons.check_circle_rounded;
      case MiniProfileSocialRelation.followBack:
        return Icons.person_add_alt_rounded;
      case MiniProfileSocialRelation.friends:
        return Icons.diversity_1_rounded;
    }
  }

  Color get color {
    switch (this) {
      case MiniProfileSocialRelation.follow:
        return RoomColors.aqua;
      case MiniProfileSocialRelation.following:
        return const Color(0xFF5E6DFF);
      case MiniProfileSocialRelation.followBack:
        return RoomColors.gold;
      case MiniProfileSocialRelation.friends:
        return RoomColors.coral;
    }
  }
}

class MiniProfileSocialActionsRow extends StatelessWidget {
  const MiniProfileSocialActionsRow({
    super.key,
    required this.relation,
    required this.relationBusy,
    required this.onRelationTap,
    required this.onMessageTap,
  });

  final MiniProfileSocialRelation relation;
  final bool relationBusy;
  final VoidCallback onRelationTap;
  final VoidCallback onMessageTap;

  @override
  Widget build(BuildContext context) {
    final relationLabel = relationBusy ? 'Please wait' : relation.label;
    return Row(
      children: [
        Expanded(
          child: _MiniProfileSocialButton(
            icon: relationBusy ? Icons.sync_rounded : relation.icon,
            label: relationLabel,
            color: relation.color,
            filled: relation == MiniProfileSocialRelation.follow || relation == MiniProfileSocialRelation.followBack,
            onTap: relationBusy ? null : onRelationTap,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniProfileSocialButton(
            icon: Icons.chat_bubble_rounded,
            label: 'Message',
            color: RoomColors.plum,
            filled: false,
            onTap: onMessageTap,
          ),
        ),
      ],
    );
  }
}

class _MiniProfileSocialButton extends StatelessWidget {
  const _MiniProfileSocialButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final background = filled ? color : Colors.white;
    final foreground = filled ? Colors.white : color;
    final borderColor = filled ? color.withValues(alpha: 0.58) : color.withValues(alpha: 0.20);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.68,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor, width: 0.9),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: filled ? 0.14 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foreground, size: 15.5),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 11.6,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: -0.05,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
