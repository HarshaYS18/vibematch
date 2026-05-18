import 'package:flutter/material.dart';

import 'room_info_sheet.dart';
import 'room_theme.dart';

class LiveRoomAnnouncementSheet extends StatelessWidget {
  const LiveRoomAnnouncementSheet({
    super.key,
    required this.controller,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          18,
          12,
          18,
          MediaQuery.paddingOf(context).bottom + 16,
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
            const SizedBox(height: 16),
            const Text(
              'Broad Announcement',
              style: TextStyle(
                color: RoomColors.plum,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Type announcement...',
                filled: true,
                fillColor: RoomColors.pearl,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => onSubmit(controller.text.trim()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: RoomColors.plum,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text('Submit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}