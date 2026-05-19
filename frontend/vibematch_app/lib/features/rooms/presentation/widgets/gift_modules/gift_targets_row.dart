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
    final allSelected =
        users.isNotEmpty && selectedUserIds.length == users.length;

    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: users.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _GiftTargetAvatar(
              selected: allSelected,
              label: 'All',
              colors: const [RoomColors.gold, RoomColors.coral],
              avatarUrl: null,
              onTap: onAllTap,
            );
          }
          final user = users[index - 1];
          return _GiftTargetAvatar(
            selected: selectedUserIds.contains(user.id),
            label: avatarLetter(user.name),
            colors: user.avatarColors,
            avatarUrl: user.avatarUrl,
            onTap: () => onUserTap(user.id),
          );
        },
      ),
    );
  }
}

class _GiftTargetAvatar extends StatelessWidget {
  const _GiftTargetAvatar({
    required this.selected,
    required this.label,
    required this.colors,
    required this.avatarUrl,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final List<Color> colors;
  final String? avatarUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? RoomColors.gold : Colors.white24,
            width: selected ? 2.2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: RoomColors.gold.withValues(alpha: 0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: colors),
          ),
          clipBehavior: Clip.antiAlias,
          child: _AvatarImageOrLabel(avatarUrl: avatarUrl, label: label),
        ),
      ),
    );
  }
}

class _AvatarImageOrLabel extends StatelessWidget {
  const _AvatarImageOrLabel({required this.avatarUrl, required this.label});

  final String? avatarUrl;
  final String label;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => _label(),
      );
    }
    return _label();
  }

  Widget _label() {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}
