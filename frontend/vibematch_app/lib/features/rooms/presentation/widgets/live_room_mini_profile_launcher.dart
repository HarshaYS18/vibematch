import 'package:flutter/material.dart';

import '../../data/room_moderation_repository.dart';
import '../controllers/live_room_profile_navigator.dart';
import '../live_room_models.dart';
import 'live_room_mini_profile_sheet.dart';
import 'mini_profile_report_sheet.dart';
import 'room_kickout_duration_sheet.dart';
import 'room_theme.dart';

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
    String? roomId,
    required ValueChanged<SeatUser> onMentionTap,
    required ValueChanged<String> onSetAdminTap,
    ValueChanged<String>? onRemoveAdminTap,
    ValueChanged<SeatUser>? onReportTap,
    ValueChanged<RoomKickoutDuration>? onKickOutDurationSelected,
    required ValueChanged<int> onLeaveAndLock,
    required ValueChanged<int> onLeaveSeatOnly,
    required ValueChanged<String> onSelfMuteToggle,
    required ValueChanged<String> onAdminMuteToggle,
    required ValueChanged<String> onGiftTap,
  }) {
    final canShowKickOut = canModerate && user.id != currentUser.id;

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
        onSendingLevelTap: () => LiveRoomProfileNavigator.openSendingExperiencePage(
          context: context,
          user: user,
        ),
        onReceivingLevelTap: () => LiveRoomProfileNavigator.openReceivingExperiencePage(
          context: context,
          user: user,
        ),
        onSentRankingTap: () => LiveRoomProfileNavigator.openSentRankingsPage(
          context: context,
          users: allRoomUsers,
        ),
        onReceivedRankingTap: () => LiveRoomProfileNavigator.openReceivedRankingsPage(
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
        onRemoveAdminTap: () {
          if (onRemoveAdminTap != null) {
            onRemoveAdminTap(user.id);
          } else {
            Navigator.pop(context);
          }
        },
        onReportTap: () {
          if (onReportTap != null) {
            onReportTap(user);
          } else {
            _openReportSheet(context: context, user: user);
          }
        },
        onLeaveAndLock: () => onLeaveAndLock(seatIndex),
        onLeaveSeatOnly: () => onLeaveSeatOnly(seatIndex),
        onSelfMuteToggle: () => onSelfMuteToggle(user.id),
        onAdminMuteToggle: () => onAdminMuteToggle(user.id),
        onGiftTap: () => onGiftTap(user.id),
        onKickOutTap: canShowKickOut && onKickOutDurationSelected != null
            ? () => _openKickOutDurationSheet(
                  context: context,
                  user: user,
                  onDurationSelected: onKickOutDurationSelected,
                )
            : null,
      ),
    );
  }

  static void _openKickOutDurationSheet({
    required BuildContext context,
    required SeatUser user,
    required ValueChanged<RoomKickoutDuration> onDurationSelected,
  }) {
    Navigator.pop(context);

    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!context.mounted) return;

      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => RoomKickoutDurationSheet(
          user: user,
          onDurationSelected: onDurationSelected,
        ),
      );
    });
  }

  static void _openReportSheet({
    required BuildContext context,
    required SeatUser user,
  }) {
    Navigator.pop(context);

    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!context.mounted) return;

      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => MiniProfileReportSheet(user: user),
      );
    });
  }
}
