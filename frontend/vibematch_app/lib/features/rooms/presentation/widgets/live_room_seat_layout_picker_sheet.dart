import 'package:flutter/material.dart';

import 'room_settings_sheet.dart';

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
    return SeatLayoutSheet(
      selectedLayout: selectedLayout,
      onSelected: onSelected,
    );
  }
}