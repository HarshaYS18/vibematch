import 'package:flutter/material.dart';

import '../../data/room_music_controller.dart';
import '../controllers/live_room_profile_navigator.dart';
import '../live_room_models.dart';
import 'live_room_blocked_list_sheet.dart';
import 'room_settings_sheet.dart';

class LiveRoomSettingsSheetModule extends StatelessWidget {
  const LiveRoomSettingsSheetModule({
    super.key,
    this.roomId = 'VM257808',
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
    required this.onAnnouncementTap,
    required this.onInboxTap,
    required this.onJoinRequestsTap,
    required this.onToggleRoomImages,
    required this.onToggleGuestMessages,
    required this.onToggleApplyOnlyMode,
    required this.onCloseRoom,
    required this.onVibeSyncTap,
    required this.onWatchPartyTap,
    required this.onClearChatTap,
    required this.onCricketModeTap,
    required this.canCloseRoom,
    this.cricketModeActive = false,
  });

  final String roomId;
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
  final VoidCallback onAnnouncementTap;
  final VoidCallback onInboxTap;
  final VoidCallback onJoinRequestsTap;
  final ValueChanged<bool> onToggleRoomImages;
  final ValueChanged<bool> onToggleGuestMessages;
  final ValueChanged<bool> onToggleApplyOnlyMode;
  final VoidCallback onCloseRoom;
  final VoidCallback onVibeSyncTap;
  final VoidCallback onWatchPartyTap;
  final VoidCallback onClearChatTap;
  final VoidCallback onCricketModeTap;
  final bool canCloseRoom;
  final bool cricketModeActive;

  void _openBlockedList(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LiveRoomBlockedListSheet(roomId: roomId),
    );
  }

  void _openMusicModule(BuildContext context) {
    Navigator.of(context).pop();
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      RoomMusicController.instance.showOverlay();
    });
  }

  @override
  Widget build(BuildContext context) {
    return RoomSettingsSheet(
      privacyMode: privacyMode,
      roomImagesEnabled: roomImagesEnabled,
      guestMessagesEnabled: guestMessagesEnabled,
      applyOnlyModeEnabled: applyOnlyModeEnabled,
      joinRequestCount: joinRequestCount,
      onBackgroundTap: onBackgroundTap,
      onCoverPhotoTap: onCoverPhotoTap,
      onCustomBackgroundTap: onCustomBackgroundTap,
      onPrivacyTap: onPrivacyTap,
      onSeatLayoutTap: onSeatLayoutTap,
      onAnnouncementTap: onAnnouncementTap,
      onInboxTap: onInboxTap,
      onJoinRequestsTap: onJoinRequestsTap,
      onVibeSyncTap: onVibeSyncTap,
      onWatchPartyTap: onWatchPartyTap,
      onCricketModeTap: onCricketModeTap,
      onReportsTap: () => LiveRoomProfileNavigator.openModulePage(
        context: context,
        title: 'Reports',
        subtitle: 'Room safety, reports, and moderation queue will connect here.',
        icon: Icons.report_gmailerrorred_rounded,
      ),
      onBlockedTap: () => _openBlockedList(context),
      onEffectsTap: () => LiveRoomProfileNavigator.openModulePage(
        context: context,
        title: 'Room effects',
        subtitle:
            'Room entrance effects, seat effects, and background effects will connect here.',
        icon: Icons.auto_awesome_rounded,
      ),
      onMusicTap: () => _openMusicModule(context),
      onToggleRoomImages: onToggleRoomImages,
      onToggleGuestMessages: onToggleGuestMessages,
      onToggleApplyOnlyMode: onToggleApplyOnlyMode,
      onClearChatTap: onClearChatTap,
      onCloseRoom: onCloseRoom,
      canCloseRoom: canCloseRoom,
      showSeatLayoutOption: !cricketModeActive,
    );
  }
}
