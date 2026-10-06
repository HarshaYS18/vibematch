import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/room_moderation_repository.dart';
import '../../controllers/live_room_profile_navigator.dart';
import '../../controllers/live_room_sheet_controller.dart';
import '../../live_room_models.dart';
import '../../widgets/live_room_info_sheet.dart';
import '../../widgets/live_room_mini_profile_launcher.dart';
import '../../widgets/room_theme.dart';
import '../chat/live_room_chat_module.dart';
import '../gifts/live_room_gifts_module.dart';
import '../lifecycle/live_room_lifecycle_module.dart';
import '../live_room_controller_bundle.dart';

class LiveRoomProfileModule {
  const LiveRoomProfileModule._();

  static void openMiniProfileFromChat(
    LiveRoomControllerBundle bundle,
    ChatEntry entry,
  ) {
    if (entry.senderId == null || entry.senderId == 'system') return;
    openMiniProfileForUser(
      bundle,
      bundle.usersController.resolveUserFromChatEntry(
        entry: entry,
        allRoomUsers: bundle.allRoomUsers,
      ),
    );
  }

  static void openMiniProfileForUser(
    LiveRoomControllerBundle bundle,
    SeatUser user,
  ) {
    final liveUser = bundle.allRoomUsers.firstWhere(
      (item) => item.id == user.id,
      orElse: () => user,
    );
    final seatIndex = bundle.seatController.seats.indexWhere(
      (seat) => seat.user?.id == liveUser.id,
    );
    openMiniProfile(bundle, liveUser, seatIndex);
  }

  static void openMiniProfile(
    LiveRoomControllerBundle bundle,
    SeatUser user,
    int seatIndex,
  ) {
    LiveRoomLifecycleModule.clearFocus(bundle);
    LiveRoomMiniProfileLauncher.open(
      context: bundle.context,
      user: user,
      seatIndex: seatIndex,
      currentUser: bundle.currentUser,
      canModerate: bundle.viewerCanManageRoom,
      allRoomUsers: bundle.allRoomUsers,
      privacyMode: bundle.privacyMode,
      roomName: bundle.roomName,
      roomId: bundle.roomId,
      onMentionTap: (targetUser) => mentionUser(bundle, targetUser),
      onSetAdminTap: (userId) => setUserAsAdmin(bundle, userId),
      onRemoveAdminTap: (userId) => removeUserAsAdmin(bundle, userId),
      onReportTap: (targetUser) => openReportForUser(bundle, targetUser),
      onKickOutDurationSelected: canKickOutUser(bundle, user)
          ? (duration) => kickOutUser(bundle, user: user, duration: duration)
          : null,
      onLeaveAndLock: (targetSeatIndex) {
        Navigator.pop(bundle.context);
        bundle.seatController.leaveAndLockSeat(targetSeatIndex);
      },
      onLeaveSeatOnly: (targetSeatIndex) {
        Navigator.pop(bundle.context);
        final seatedUser =
            targetSeatIndex >= 0 &&
                targetSeatIndex < bundle.seatController.seats.length
            ? bundle.seatController.seats[targetSeatIndex].user
            : null;
        if (seatedUser?.id == bundle.currentUser.id) {
          bundle.seatController.leaveAndLockSeat(targetSeatIndex);
        } else {
          bundle.seatController.leaveSeatOnly(targetSeatIndex);
        }
      },
      onSelfMuteToggle: (userId) {
        Navigator.pop(bundle.context);
        bundle.seatController.toggleSelfMute(userId);
      },
      onAdminMuteToggle: (userId) {
        Navigator.pop(bundle.context);
        bundle.seatController.toggleAdminMute(userId);
      },
      onGiftTap: (userId) {
        Navigator.pop(bundle.context);
        bundle.setRoomState(() {
          LiveRoomGiftsModule.controllerFor(bundle).selectedReceiverIds
            ..clear()
            ..add(userId);
        });
        LiveRoomGiftsModule.openGiftPanel(bundle);
      },
    );
  }

  static bool canKickOutUser(LiveRoomControllerBundle bundle, SeatUser target) {
    return bundle.moderationController.canKickOutUser(
      target: target,
      canManageRoom: bundle.viewerCanManageRoom,
    );
  }

  static Future<void> kickOutUser(
    LiveRoomControllerBundle bundle, {
    required SeatUser user,
    required RoomKickoutDuration duration,
  }) async {
    final result = await bundle.moderationController.kickOutUser(
      roomId: bundle.roomId,
      target: user,
      duration: duration,
      canManageRoom: bundle.viewerCanManageRoom,
    );
    if (!bundle.mounted) return;
    final systemMessage = result.systemMessage;
    if (systemMessage != null) {
      LiveRoomChatModule.insertSystemMessage(bundle, systemMessage);
    }
    final removedUserId = result.removedUserId;
    if (removedUserId != null) {
      bundle.seatController.kickUserFromRoom(
        userId: removedUserId,
        duration: duration.apiValue,
      );
    }
    final toastMessage = result.toastMessage;
    if (toastMessage != null) RoomToast.show(bundle.context, toastMessage);
  }

  static void mentionUser(LiveRoomControllerBundle bundle, SeatUser user) {
    Navigator.pop(bundle.context);

    bundle.messageController.insertMention(user.name);

    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (!bundle.mounted) return;
      LiveRoomChatModule.openMessageComposerWithMention(bundle);
    });
  }

  static void openMentionedUserProfile(
    LiveRoomControllerBundle bundle,
    String mentionName,
  ) {
    final cleanMention = mentionName.trim().toLowerCase();
    if (cleanMention.isEmpty) return;

    final user = bundle.allRoomUsers.where((item) {
      final cleanName = item.name.trim().toLowerCase();
      final cleanUsername = cleanName.replaceAll(' ', '_');
      return cleanName == cleanMention ||
          cleanUsername == cleanMention ||
          cleanName.replaceAll(' ', '') == cleanMention.replaceAll('_', '');
    }).firstOrNull;

    if (user == null) {
      RoomToast.show(
        bundle.context,
        '@$mentionName profile not found in this room',
      );
      return;
    }

    LiveRoomProfileNavigator.openExistingPublicProfile(
      context: bundle.context,
      user: user,
      privacyMode: bundle.privacyMode,
      roomName: bundle.roomName,
    );
  }

  static void setUserAsAdmin(LiveRoomControllerBundle bundle, String userId) {
    Navigator.pop(bundle.context);
    if (!bundle.viewerCanManageAdmins) {
      RoomToast.show(bundle.context, 'Only channel host can add admins');
      return;
    }
    bundle.seatController.setUserAsAdmin(userId);
    LiveRoomLifecycleModule.clearFocus(bundle);
  }

  static void removeUserAsAdmin(
    LiveRoomControllerBundle bundle,
    String userId,
  ) {
    Navigator.pop(bundle.context);
    if (!bundle.viewerCanManageAdmins) {
      RoomToast.show(bundle.context, 'Only channel host can remove admins');
      return;
    }
    bundle.seatController.removeUserAsAdmin(userId);
    LiveRoomLifecycleModule.clearFocus(bundle);
  }

  static void addRoomAdminFromInfo(
    LiveRoomControllerBundle bundle,
    SeatUser user,
  ) {
    if (!bundle.viewerCanManageAdmins) {
      RoomToast.show(bundle.context, 'Only channel host can add admins');
      return;
    }
    bundle.seatController.setUserAsAdmin(user.id);
    LiveRoomLifecycleModule.clearFocus(bundle);
  }

  static void removeRoomAdminFromInfo(
    LiveRoomControllerBundle bundle,
    SeatUser user,
  ) {
    if (!bundle.viewerCanManageAdmins) {
      RoomToast.show(bundle.context, 'Only channel host can remove admins');
      return;
    }
    bundle.seatController.removeUserAsAdmin(user.id);
    LiveRoomLifecycleModule.clearFocus(bundle);
  }

  static void removeRoomMemberFromInfo(
    LiveRoomControllerBundle bundle,
    SeatUser user,
  ) {
    if (!bundle.viewerCanManageAdmins) {
      RoomToast.show(
        bundle.context,
        'Only channel host can remove room members',
      );
      return;
    }
    bundle.removeRoomMembership(user);
    RoomToast.show(bundle.context, 'Removing ${user.name} from room members');
    LiveRoomLifecycleModule.clearFocus(bundle);
  }

  static void openReportForUser(
    LiveRoomControllerBundle bundle,
    SeatUser user,
  ) {
    Navigator.pop(bundle.context);
    openInfoSheet(
      bundle,
      'Report submitted',
      '${user.name} has been sent to the room safety review queue.',
    );
  }

  static void openInfoSheet(
    LiveRoomControllerBundle bundle,
    String title,
    String body,
  ) {
    LiveRoomSheetController.showTransparentSheet<void>(
      context: bundle.context,
      builder: (context) => LiveRoomInfoSheet(title: title, body: body),
    );
  }
}

extension _FirstOrNullOnIterable<T> on Iterable<T> {
  T? get firstOrNull {
    for (final item in this) {
      return item;
    }
    return null;
  }
}
