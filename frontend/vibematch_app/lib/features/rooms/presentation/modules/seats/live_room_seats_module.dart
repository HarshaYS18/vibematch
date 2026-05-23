import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/live_room_media_signaling_service.dart';
import '../../../data/live_room_member_request_service.dart';
import '../../controllers/live_room_sheet_controller.dart';
import '../../live_room_models.dart';
import '../../widgets/live_room_invite_sheet.dart';
import '../../widgets/room_theme.dart';
import '../live_room_controller_bundle.dart';
import '../lifecycle/live_room_lifecycle_module.dart';
import '../profile/live_room_profile_module.dart';

class LiveRoomSeatsModule {
  const LiveRoomSeatsModule._();

  static void onSeatTap(LiveRoomControllerBundle bundle, int index) {
    final seat = bundle.seatController.seats[index];
    if (seat.locked) {
      if (bundle.viewerCanManageRoom) {
        bundle.seatController.toggleSelectedSeat(index);
      } else {
        RoomToast.show(bundle.context, 'This seat is locked');
      }
      return;
    }

    if (seat.user == null && !bundle.viewerCanManageRoom) {
      if (bundle.applyOnlyModeEnabled) {
        applyForSeat(bundle, index);
      } else {
        bundle.seatController.occupySeat(index);
      }
      return;
    }

    if (seat.user == null && bundle.viewerCanManageRoom) {
      bundle.seatController.toggleSelectedSeat(index);
    }
  }

  static void onUserTap(LiveRoomControllerBundle bundle, int index) {
    final user = bundle.seatController.seats[index].user;
    if (user == null) return;
    LiveRoomProfileModule.openMiniProfile(bundle, user, index);
  }

  static void approveSeatApplication(
    LiveRoomControllerBundle bundle,
    ChatEntry entry,
  ) {
    bundle.seatController.approveSeatApplication(
      entry: entry,
      messages: bundle.roomMessageController.messages,
      allRoomUsers: bundle.allRoomUsers,
    );
  }

  static void rejectSeatApplication(
    LiveRoomControllerBundle bundle,
    ChatEntry entry,
  ) {
    bundle.seatController.rejectSeatApplication(
      entry: entry,
      messages: bundle.roomMessageController.messages,
    );
  }

  static void applyForSeat(LiveRoomControllerBundle bundle, int index) {
    bundle.seatController.applyForSeat(
      index: index,
      messages: bundle.roomMessageController.messages,
    );
  }

  static void inviteSeat(LiveRoomControllerBundle bundle, int index) {
    bundle.seatController.clearSelectedSeat();
    openSeatInviteSheet(bundle, index);
  }

  static void openSeatInviteSheet(
    LiveRoomControllerBundle bundle,
    int seatIndex,
  ) {
    LiveRoomLifecycleModule.clearFocus(bundle);
    final inviteUsers = bundle.usersController.buildSeatInviteUsers(
      allRoomUsers: bundle.allRoomUsers,
      seatedUsers: bundle.roomUsers,
    );
    LiveRoomSheetController.showTransparentSheet<void>(
      context: bundle.context,
      builder: (_) => LiveRoomInviteSheet(
        seatIndex: seatIndex,
        users: inviteUsers,
        onInvite: (user) =>
            sendSeatInvite(bundle, seatIndex: seatIndex, invitedUser: user),
      ),
    );
  }

  static void sendSeatInvite(
    LiveRoomControllerBundle bundle, {
    required int seatIndex,
    required SeatUser invitedUser,
  }) {
    Navigator.pop(bundle.context);
    LiveRoomLifecycleModule.clearFocus(bundle);
    final sent = bundle.seatController.inviteUserToSeat(
      seatIndex: seatIndex,
      invitedUser: invitedUser,
    );
    if (sent) {
      RoomToast.show(bundle.context, 'Seat invite sent to ${invitedUser.name}');
    }
  }

  static void handleSeatInviteUpdate(LiveRoomControllerBundle bundle) {
    final invite = LiveRoomMediaSignalingService.instance.seatInvite.value;
    bundle.seatInviteAutoHideTimer?.cancel();
    bundle.seatInviteAutoHideTimer = null;

    if (invite == null ||
        invite.roomId != bundle.roomId ||
        invite.seatIndex < 0) {
      if (bundle.pendingSeatInvite != null && bundle.mounted) {
        bundle.setRoomState(() => bundle.pendingSeatInvite = null);
      }
      return;
    }

    if (!bundle.mounted) return;
    bundle.setRoomState(() {
      bundle.pendingSeatInvite = PendingSeatInvite(
        inviterName: invite.inviterName,
        invitedUser: bundle.currentUser,
        seatIndex: invite.seatIndex,
      );
    });
    bundle.seatInviteAutoHideTimer = Timer(const Duration(seconds: 15), () {
      if (!bundle.mounted) return;
      LiveRoomMediaSignalingService.instance.clearSeatInvite();
      bundle.setRoomState(() => bundle.pendingSeatInvite = null);
    });
  }

  static void rejectSeatInvite(LiveRoomControllerBundle bundle) {
    final invite = bundle.pendingSeatInvite;
    if (invite == null) return;

    bundle.seatInviteAutoHideTimer?.cancel();
    bundle.seatInviteAutoHideTimer = null;

    bundle.setRoomState(() {
      bundle.pendingSeatInvite = null;
    });
    LiveRoomMediaSignalingService.instance.rejectSeatInvite(
      seatIndex: invite.seatIndex,
    );

    RoomToast.show(bundle.context, 'Seat invite rejected');
  }

  static void acceptSeatInvite(LiveRoomControllerBundle bundle) {
    final invite = bundle.pendingSeatInvite;
    if (invite == null) return;

    LiveRoomMediaSignalingService.instance.acceptSeatInvite(
      seatIndex: invite.seatIndex,
    );

    bundle.seatInviteAutoHideTimer?.cancel();
    bundle.seatInviteAutoHideTimer = null;

    bundle.setRoomState(() {
      bundle.pendingSeatInvite = null;
    });
    LiveRoomMediaSignalingService.instance.clearSeatInvite();
  }

  static void handleJoinRoom(LiveRoomControllerBundle bundle) {
    LiveRoomLifecycleModule.clearFocus(bundle);

    if (bundle.currentUserIsMember) {
      RoomToast.show(
        bundle.context,
        'You are already a room member of ${bundle.roomName}',
      );
      return;
    }

    if (bundle.joinRequestPending) {
      RoomToast.show(
        bundle.context,
        'Your room member request is already pending.',
      );
      return;
    }

    LiveRoomMemberRequestService.instance.requestMembership();
    RoomToast.show(bundle.context, 'Room member request sent to channel host');
  }

  static void autoOccupySeatOneForHostOrAdmin(LiveRoomControllerBundle bundle) {
    bundle.hostSeatOneTimer?.cancel();
    bundle.hostSeatOneRetryTimer?.cancel();

    if (!bundle.viewerCanManageRoom) return;

    bundle.hostSeatOneTimer = Timer(
      const Duration(milliseconds: 260),
      () => tryOccupySeatOneForHostOrAdmin(bundle),
    );
    bundle.hostSeatOneRetryTimer = Timer(
      const Duration(milliseconds: 1300),
      () => tryOccupySeatOneForHostOrAdmin(bundle),
    );
  }

  static void tryOccupySeatOneForHostOrAdmin(LiveRoomControllerBundle bundle) {
    if (!bundle.mounted || !bundle.viewerCanManageRoom) return;
    if (bundle.seatController.seats.isEmpty) return;

    if (bundle.seatController.currentUserIsSeated) {
      bundle.hostSeatOneTimer?.cancel();
      bundle.hostSeatOneRetryTimer?.cancel();
      return;
    }

    final firstSeat = bundle.seatController.seats.first;
    if (firstSeat.locked) return;
    if (firstSeat.user != null) return;

    bundle.hostSeatOneTimer?.cancel();
    bundle.hostSeatOneRetryTimer?.cancel();
    bundle.seatController.occupySeat(0);
  }
}
