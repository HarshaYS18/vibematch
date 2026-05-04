import 'package:flutter/material.dart';

import '../../live_room_models.dart';
import '../room_theme.dart';

class GiftTargetsRow extends StatelessWidget {
  const GiftTargetsRow({
    super.key,
    required this.users,
    required this.selectedUserIds,
    required this.onAllTap,
    required this.onUserTap,
  });

  final List<SeatUser> users;
  final Set<String> selectedUserIds;
  final VoidCallback onAllTap;
  final ValueChanged<String> onUserTap;

  @override
  Widget build(BuildContext context) {
    final allSelected = users.isNotEmpty && selectedUserIds.length == users.length;

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: users.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _GiftTargetAvatar(
              selected: allSelected,
              label: 'All',
              colors: const [RoomColors.gold, RoomColors.coral],
              onTap: onAllTap,
            );
          }
          final user = users[index - 1];
          return _GiftTargetAvatar(
            selected: selectedUserIds.contains(user.id),
            label: avatarLetter(user.name),
            colors: user.avatarColors,
            onTap: () => onUserTap(user.id),
          );
        },
      ),
    );
  }
}

class _GiftTargetAvatar extends StatelessWidget {
  const _GiftTargetAvatar({required this.selected, required this.label, required this.colors, required this.onTap});

  final bool selected;
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: selected ? RoomColors.gold : Colors.white24, width: selected ? 2 : 1),
        ),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: colors)),
          child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }
}
