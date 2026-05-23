import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/live_room_sheet_controller.dart';
import '../../widgets/live_room_users_sheet.dart';
import '../../widgets/room_level_sheet.dart';
import '../../widgets/room_theme.dart';
import '../lifecycle/live_room_lifecycle_module.dart';
import '../live_room_controller_bundle.dart';
import '../profile/live_room_profile_module.dart';
import '../rankings/live_room_rankings_entry_module.dart';

class LiveRoomHeaderModule {
  const LiveRoomHeaderModule._();

  static void openRoomUsersSheet(LiveRoomControllerBundle bundle) {
    LiveRoomSheetController.showTransparentSheet<void>(
      context: bundle.context,
      isScrollControlled: true,
      builder: (_) => LiveRoomUsersSheet(
        users: bundle.allRoomUsers,
        onUserTap: (user) {
          Navigator.pop(bundle.context);
          Future<void>.delayed(const Duration(milliseconds: 80), () {
            if (bundle.mounted) {
              LiveRoomProfileModule.openMiniProfileForUser(bundle, user);
            }
          });
        },
      ),
    );
  }

  static void openRoomRankingsSheet(LiveRoomControllerBundle bundle) {
    LiveRoomRankingsEntryModule.openRoomRankingsSheet(bundle);
  }

  static void openRoomLevelPage(LiveRoomControllerBundle bundle) {
    LiveRoomLifecycleModule.clearFocus(bundle);
    RoomLevelSheet.show(
      bundle.context,
      roomName: bundle.roomName,
      roomPublicId: bundle.roomId,
      fallbackLevel: 1,
    );
  }

  static void openEditRoomNameSheet(LiveRoomControllerBundle bundle) {
    LiveRoomLifecycleModule.clearFocus(bundle);
    if (!bundle.viewerCanManageAdmins) {
      RoomToast.show(bundle.context, 'Only channel host can edit room name');
      return;
    }
    LiveRoomSheetController.showTransparentSheet<void>(
      context: bundle.context,
      isScrollControlled: true,
      builder: (sheetContext) => _RoomNameEditSheet(
        initialName: bundle.roomName,
        onSubmit: (name) {
          Navigator.pop(sheetContext);
          unawaited(saveRoomName(bundle, name));
        },
      ),
    );
  }

  static Future<void> saveRoomName(
    LiveRoomControllerBundle bundle,
    String name,
  ) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      RoomToast.show(bundle.context, 'Room name cannot be empty');
      return;
    }
    try {
      await bundle.roomStateController.setRoomName(cleanName);
      if (!bundle.mounted) return;
      RoomToast.show(bundle.context, 'Room name updated');
    } catch (error) {
      if (!bundle.mounted) return;
      RoomToast.show(
        bundle.context,
        error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}

class _RoomNameEditSheet extends StatefulWidget {
  const _RoomNameEditSheet({required this.initialName, required this.onSubmit});

  final String initialName;
  final ValueChanged<String> onSubmit;

  @override
  State<_RoomNameEditSheet> createState() => _RoomNameEditSheetState();
}

class _RoomNameEditSheetState extends State<_RoomNameEditSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
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
              'Edit Room Name',
              style: TextStyle(
                color: RoomColors.plum,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLength: 120,
              decoration: InputDecoration(
                hintText: 'Room name',
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
                onPressed: () => widget.onSubmit(_controller.text.trim()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: RoomColors.plum,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
