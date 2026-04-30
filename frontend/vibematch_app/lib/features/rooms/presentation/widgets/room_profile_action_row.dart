import 'package:flutter/material.dart';

class RoomProfileActionRow extends StatelessWidget {
  const RoomProfileActionRow({
    super.key,
    required this.isSelf,
    required this.canModerate,
    required this.selfMuted,
    required this.adminMuted,
    required this.onLeaveAndLock,
    required this.onLeaveSeatOnly,
    required this.onSelfMuteToggle,
    required this.onAdminMuteToggle,
    this.onKickOutTap,
  });

  final bool isSelf;
  final bool canModerate;
  final bool selfMuted;
  final bool adminMuted;
  final VoidCallback onLeaveAndLock;
  final VoidCallback onLeaveSeatOnly;
  final VoidCallback onSelfMuteToggle;
  final VoidCallback onAdminMuteToggle;
  final VoidCallback? onKickOutTap;

  static const Color _iconColor = Color(0xFF3B3B3F);
  static const Color _labelColor = Color(0xFF8F8F95);
  static const Color _dividerColor = Color(0xFFE4E1E6);

  @override
  Widget build(BuildContext context) {
    final actions = <_ProfileActionItemData>[
      if (isSelf)
        _ProfileActionItemData(
          icon: const _LeaveSeatIcon(color: _iconColor),
          label: 'Leave',
          onTap: onLeaveSeatOnly,
        ),
      if (canModerate && !isSelf)
        _ProfileActionItemData(
          icon: const Icon(Icons.lock_rounded),
          label: 'Leave & Lock',
          onTap: onLeaveAndLock,
        ),
      if (canModerate && !isSelf)
        _ProfileActionItemData(
          icon: const _LeaveSeatIcon(color: _iconColor),
          label: 'Leave',
          onTap: onLeaveSeatOnly,
        ),
      if (canModerate && !isSelf && onKickOutTap != null)
        _ProfileActionItemData(
          icon: const Icon(Icons.person_remove_alt_1_rounded),
          label: 'Kick out',
          onTap: onKickOutTap!,
        ),
      if (isSelf)
        _ProfileActionItemData(
          icon: Icon(selfMuted ? Icons.mic_off_rounded : Icons.mic_rounded),
          label: selfMuted ? 'Turn On' : 'Turn Off',
          onTap: onSelfMuteToggle,
        )
      else if (canModerate)
        _ProfileActionItemData(
          icon: Icon(adminMuted ? Icons.mic_rounded : Icons.mic_off_rounded),
          label: adminMuted ? 'Turn On' : 'Turn Off',
          onTap: onAdminMuteToggle,
        ),
    ];

    if (actions.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 62,
      margin: const EdgeInsets.only(top: 2, bottom: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _dividerColor.withValues(alpha: 0.85)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            Expanded(child: _ProfileActionTile(data: actions[i])),
            if (i != actions.length - 1)
              Container(
                width: 1,
                height: 34,
                color: _dividerColor,
              ),
          ],
        ],
      ),
    );
  }
}

class _ProfileActionItemData {
  const _ProfileActionItemData({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;
}

class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({required this.data});

  final _ProfileActionItemData data;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: data.onTap,
      child: SizedBox.expand(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconTheme(
              data: const IconThemeData(
                color: RoomProfileActionRow._iconColor,
                size: 22,
              ),
              child: data.icon,
            ),
            const SizedBox(height: 5),
            Text(
              data.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: RoomProfileActionRow._labelColor,
                fontSize: 11.2,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaveSeatIcon extends StatelessWidget {
  const _LeaveSeatIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 3,
            top: 1,
            child: Icon(Icons.meeting_room_rounded, color: color, size: 20),
          ),
          Positioned(
            right: 1,
            top: 5,
            child: Icon(Icons.arrow_forward_rounded, color: color, size: 17),
          ),
        ],
      ),
    );
  }
}
