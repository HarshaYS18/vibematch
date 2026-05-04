import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'room_theme.dart';
import 'room_user_list_components.dart';

class RoomUserListSheet extends StatelessWidget {
  const RoomUserListSheet({
    super.key,
    required this.users,
    required this.onUserTap,
  });

  final List<SeatUser> users;
  final ValueChanged<SeatUser> onUserTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.74,
      ),
      padding: EdgeInsets.fromLTRB(
        18,
        12,
        18,
        MediaQuery.paddingOf(context).bottom + 18,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const SizedBox(height: 14),
          RoomUserListHeader(count: users.length),
          const SizedBox(height: 14),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: users.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final user = users[index];
                return RoomUserListCard(
                  user: user,
                  onTap: () => onUserTap(user),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
