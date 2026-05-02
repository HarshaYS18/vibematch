import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../live_room_models.dart';
import '../room_theme.dart';

class LiveRoomGiftReceiverStrip extends StatelessWidget {
  const LiveRoomGiftReceiverStrip({
    super.key,
    required this.users,
    required this.selectedReceiverIdsListenable,
    required this.onReceiverToggle,
  });

  final List<SeatUser> users;
  final ValueListenable<Set<String>> selectedReceiverIdsListenable;
  final ValueChanged<String> onReceiverToggle;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        height: 38,
        child: ValueListenableBuilder<Set<String>>(
          valueListenable: selectedReceiverIdsListenable,
          builder: (context, selectedIds, _) {
            final allSelected = users.isNotEmpty && selectedIds.length == users.length;
            return ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: users.length + 1,
              separatorBuilder: (context, index) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _ReceiverAvatarOptimized(
                    selected: allSelected,
                    label: 'All',
                    colors: const [RoomColors.gold, RoomColors.coral],
                    onTap: () => onReceiverToggle('__all__'),
                  );
                }
                final user = users[index - 1];
                return _ReceiverAvatarOptimized(
                  selected: selectedIds.contains(user.id),
                  label: avatarLetter(user.name),
                  colors: user.avatarColors,
                  onTap: () => onReceiverToggle(user.id),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ReceiverAvatarOptimized extends StatelessWidget {
  const _ReceiverAvatarOptimized({
    required this.selected,
    required this.label,
    required this.colors,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 36,
        height: 36,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? RoomColors.gold : Colors.white24,
            width: selected ? 2 : 1,
          ),
        ),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: colors),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
