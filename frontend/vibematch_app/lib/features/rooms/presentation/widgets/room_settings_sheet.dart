import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'room_settings/room_settings_main_section.dart';
import 'room_settings/room_settings_modes_section.dart';
import 'room_settings/room_settings_permissions_section.dart';
import 'room_settings/room_settings_sheet_header.dart';
import 'room_theme.dart';

class RoomSettingsSheet extends StatelessWidget {
  const RoomSettingsSheet({
    super.key,
    required this.privacyMode,
    required this.roomImagesEnabled,
    required this.guestMessagesEnabled,
    required this.applyOnlyModeEnabled,
    required this.joinRequestCount,
    required this.onBackgroundTap,
    required this.onCoverPhotoTap,
    required this.onCustomBackgroundTap,
    required this.onPrivacyTap,
    required this.onSeatLayoutTap,
    required this.onToggleRoomImages,
    required this.onToggleGuestMessages,
    required this.onToggleApplyOnlyMode,
    required this.onJoinRequestsTap,
    required this.onCloseRoom,
    required this.onAnnouncementTap,
    required this.onInboxTap,
    required this.onReportsTap,
    required this.onBlockedTap,
    required this.onEffectsTap,
    required this.onMusicTap,
    required this.onVibeSyncTap,
    required this.onWatchPartyTap,
    required this.onCricketModeTap,
    required this.onClearChatTap,
    required this.canCloseRoom,
  });

  final RoomPrivacyMode privacyMode;
  final bool roomImagesEnabled;
  final bool guestMessagesEnabled;
  final bool applyOnlyModeEnabled;
  final int joinRequestCount;
  final VoidCallback onBackgroundTap;
  final VoidCallback onCoverPhotoTap;
  final VoidCallback onCustomBackgroundTap;
  final VoidCallback onPrivacyTap;
  final VoidCallback onSeatLayoutTap;
  final ValueChanged<bool> onToggleRoomImages;
  final ValueChanged<bool> onToggleGuestMessages;
  final ValueChanged<bool> onToggleApplyOnlyMode;
  final VoidCallback onJoinRequestsTap;
  final VoidCallback onCloseRoom;
  final VoidCallback onAnnouncementTap;
  final VoidCallback onInboxTap;
  final VoidCallback onReportsTap;
  final VoidCallback onBlockedTap;
  final VoidCallback onEffectsTap;
  final VoidCallback onMusicTap;
  final VoidCallback onVibeSyncTap;
  final VoidCallback onWatchPartyTap;
  final VoidCallback onCricketModeTap;
  final VoidCallback onClearChatTap;
  final bool canCloseRoom;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.58,
      child: Container(
        padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.paddingOf(context).bottom + 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(width: 42),
            const SizedBox(height: 6),
            const RoomSettingsSheetHeader(),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                children: [
                  RoomSettingsModesSection(
                    onVibeSyncTap: onVibeSyncTap,
                    onWatchPartyTap: onWatchPartyTap,
                    onCricketModeTap: onCricketModeTap,
                  ),
                  const SizedBox(height: 11),
                  RoomSettingsMainSection(
                    privacyMode: privacyMode,
                    joinRequestCount: joinRequestCount,
                    onBackgroundTap: onBackgroundTap,
                    onCoverPhotoTap: onCoverPhotoTap,
                    onCustomBackgroundTap: onCustomBackgroundTap,
                    onPrivacyTap: onPrivacyTap,
                    onSeatLayoutTap: onSeatLayoutTap,
                    onAnnouncementTap: onAnnouncementTap,
                    onJoinRequestsTap: onJoinRequestsTap,
                    onEffectsTap: onEffectsTap,
                    onMusicTap: onMusicTap,
                    onBlockedTap: onBlockedTap,
                    onReportsTap: onReportsTap,
                    onClearChatTap: onClearChatTap,
                  ),
                  const SizedBox(height: 11),
                  RoomSettingsPermissionsSection(
                    roomImagesEnabled: roomImagesEnabled,
                    guestMessagesEnabled: guestMessagesEnabled,
                    applyOnlyModeEnabled: applyOnlyModeEnabled,
                    onToggleRoomImages: onToggleRoomImages,
                    onToggleGuestMessages: onToggleGuestMessages,
                    onToggleApplyOnlyMode: onToggleApplyOnlyMode,
                    onCloseRoom: onCloseRoom,
                    canCloseRoom: canCloseRoom,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
