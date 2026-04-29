import 'package:flutter/material.dart';

class HomeRoomSectionHeader extends StatelessWidget {
  const HomeRoomSectionHeader({
    super.key,
    required this.selectedCategory,
    required this.totalRooms,
  });

  final String selectedCategory;
  final int totalRooms;

  @override
  Widget build(BuildContext context) {
    final title = selectedCategory == 'Following'
        ? 'Following rooms'
        : selectedCategory == 'Trending'
            ? 'Trending rooms'
            : '$selectedCategory rooms';

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF251538),
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            '$totalRooms found',
            style: const TextStyle(
              color: Color(0xFF7B6A86),
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
