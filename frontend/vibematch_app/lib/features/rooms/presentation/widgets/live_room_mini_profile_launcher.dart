import 'package:flutter/material.dart';

import '../controllers/live_room_profile_navigator.dart';
import '../live_room_models.dart';
import 'live_room_mini_profile_sheet.dart';

class LiveRoomMiniProfileLauncher {
  const LiveRoomMiniProfileLauncher._();

  static void open({
    required BuildContext context,
    required SeatUser user,
    required int seatIndex,
    required SeatUser currentUser,
    required bool canModerate,
    required List<SeatUser> allRoomUsers,
    required RoomPrivacyMode privacyMode,
    required String roomName,
    required ValueChanged<SeatUser> onMentionTap,
    required ValueChanged<String> onSetAdminTap,
    required ValueChanged<int> onLeaveAndLock,
    required ValueChanged<String> onSelfMuteToggle,
    required ValueChanged<String> onAdminMuteToggle,
    required ValueChanged<String> onGiftTap,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LiveRoomMiniProfileSheet(
        user: user,
        currentUser: currentUser,
        canModerate: canModerate,
        onAvatarTap: () {
          Navigator.pop(context);
          LiveRoomProfileNavigator.openExistingPublicProfile(
            context: context,
            user: user,
            privacyMode: privacyMode,
            roomName: roomName,
          );
        },
        onVipTap: () => LiveRoomProfileNavigator.openVipCentrePage(
          context: context,
          user: user,
        ),
        onSendingLevelTap:
            () => LiveRoomProfileNavigator.openSendingExperiencePage(
                  context: context,
                  user: user,
                ),
        onReceivingLevelTap:
            () => LiveRoomProfileNavigator.openReceivingExperiencePage(
                  context: context,
                  user: user,
                ),
        onSentRankingTap: () => LiveRoomProfileNavigator.openSentRankingsPage(
          context: context,
          users: allRoomUsers,
        ),
        onReceivedRankingTap:
            () => LiveRoomProfileNavigator.openReceivedRankingsPage(
                  context: context,
                  users: allRoomUsers,
                ),
        onFamilyTap: () => LiveRoomProfileNavigator.openFamilyPage(
          context: context,
          user: user,
        ),
        onRelationshipTap: () => LiveRoomProfileNavigator.openLoveAndBondCentre(
          context: context,
          user: user,
        ),
        onMedalsTap: () => LiveRoomProfileNavigator.openMedalsPage(
          context: context,
          user: user,
        ),
        onMentionTap: () => onMentionTap(user),
        onSetAdminTap: () => onSetAdminTap(user.id),
        onLeaveAndLock: () => onLeaveAndLock(seatIndex),
        onSelfMuteToggle: () => onSelfMuteToggle(user.id),
        onAdminMuteToggle: () => onAdminMuteToggle(user.id),
        onGiftTap: () => onGiftTap(user.id),
      ),
    );
  }
}
