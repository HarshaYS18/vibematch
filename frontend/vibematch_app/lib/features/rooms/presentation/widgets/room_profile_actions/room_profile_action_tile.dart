import 'package:flutter/material.dart';

import 'room_profile_action_colors.dart';
import 'room_profile_action_item_data.dart';

class RoomProfileActionTile extends StatelessWidget {
  const RoomProfileActionTile({super.key, required this.data});

  final RoomProfileActionItemData data;

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
                color: RoomProfileActionColors.icon,
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
                color: RoomProfileActionColors.label,
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
