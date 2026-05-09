import 'package:flutter/material.dart';

import '../../data/live_room_media_signaling_service.dart';
import '../../data/room_moderation_repository.dart';
import '../controllers/live_room_profile_navigator.dart';
import '../live_room_models.dart';
import 'live_room_mini_profile_sheet.dart';
import 'mini_profile_report_sheet.dart';
import 'rankings/room_rankings_models.dart';
import 'rankings/room_rankings_sheet.dart';
import 'room_kickout_duration_sheet.dart';

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
    final effectiveCurrentUser = LiveRoomMediaSignalingService.instance.effectiveCurrentUser(currentUser);
    final viewerPower = _roomPower(effectiveCurrentUser);
    final targetPower = _roomPower(user);
    final canModerateTarget = user.id != effectiveCurrentUser.id && targetPower < 100 && ((viewerPower >= 100 && targetPower < 100) || (viewerPower >= 90 && targetPower < 90));
    final canShowKickOut = canModerateTarget;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LiveRoomMiniProfileSheet(
        user: user,
        currentUser: effectiveCurrentUser,
        canModerate: canModerateTarget,
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
        onSvipTap: () => LiveRoomProfileNavigator.openSvipCentrePage(
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
        onSentRankingTap: () => _openRankingsSheet(
          context: context,
          roomId: roomId,
          roomName: roomName,
          users: allRoomUsers,
          initialCategory: RoomRankingCategory.sent,
        ),
        onReceivedRankingTap: () => _openRankingsSheet(
          context: context,
          roomId: roomId,
          roomName: roomName,
          users: allRoomUsers,
          initialCategory: RoomRankingCategory.received,
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
        onSocialRelationTap: () => _openRankingsSheet(
          context: context,
          roomId: roomId,
          roomName: roomName,
          users: allRoomUsers,
          initialCategory: RoomRankingCategory.relation,
        ),
        onMessageTap: () => _openMessageInfo(context: context, user: user),
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

  static int _roomPower(SeatUser user) {
    final id = user.id.toLowerCase();
    final role = user.roleLabel.toLowerCase();
    final isOwner = user.isHost ||
        id == 'user_6922022' ||
        id == 'founder_owner' ||
        role.contains('founder owner') ||
        role.contains('super owner') ||
        role.contains('owner') ||
        role.contains('channel host') ||
        role == 'host';
    if (isOwner) return 100;

    final isChannelAdmin = user.isRoomAdmin || role.contains('channel admin') || role.contains('room admin') || role.contains('administrator');
    if (isChannelAdmin) return 90;

    return 0;
  }

  static void _openRankingsSheet({
    required BuildContext context,
    required String? roomId,
    required String roomName,
    required List<SeatUser> users,
    required RoomRankingCategory initialCategory,
  }) {
    Navigator.pop(context);

    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!context.mounted) return;

      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => RoomRankingsSheet(
          roomPublicId: roomId ?? 'unknown_room',
          roomName: roomName,
          users: users,
          initialCategory: initialCategory,
          initialPeriod: RoomRankingPeriod.monthly,
        ),
      );
    });
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

  static void _openMessageInfo({
    required BuildContext context,
    required SeatUser user,
  }) {
    Navigator.pop(context);

    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!context.mounted) return;
      LiveRoomProfileNavigator.openModulePage(
        context: context,
        title: 'Message ${user.name}',
        subtitle:
            'Direct message composer for ${user.name} will open here. Stranger-message and mutual-friend rules will connect to Inbox backend later.',
        icon: Icons.chat_bubble_rounded,
      );
    });
  }
}
