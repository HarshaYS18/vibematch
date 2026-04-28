import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'room_theme.dart';

class LiveRoomSeatLayoutPickerSheet extends StatelessWidget {
  const LiveRoomSeatLayoutPickerSheet({
    super.key,
    required this.selectedLayout,
    required this.onSelected,
  });

  final String selectedLayout;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final layouts = [
      ...SeatLayoutSpec.withoutHostLayouts,
      ...SeatLayoutSpec.withHostLayouts,
    ];

    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        MediaQuery.paddingOf(context).bottom + 10,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(width: 42),
          const SizedBox(height: 8),
          const Text(
            'Seat Layout',
            style: TextStyle(
              color: RoomColors.plum,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: layouts.map((layout) {
              final spec = SeatLayoutSpec.parse(layout);
              final selected = layout == selectedLayout;
              return InkWell(
                borderRadius: BorderRadius.circular(15),
                onTap: () => onSelected(layout),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: selected ? RoomColors.plum : const Color(0xFFFCFAF6),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: const Color(0xFFE8DDCF)),
                  ),
                  child: Text(
                    spec.label,
                    style: TextStyle(
                      color: selected ? Colors.white : RoomColors.plum,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
