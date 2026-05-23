import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/chat_moderation_api_service.dart';
import '../../data/live_room_media_signaling_service.dart';
import '../../data/live_room_member_request_service.dart';
import '../../data/live_room_membership_service.dart';
import '../controllers/live_room_gift_controller.dart';
import '../controllers/live_room_message_controller.dart';
import '../controllers/live_room_mention_text_controller.dart';
import '../controllers/live_room_moderation_controller.dart';
import '../controllers/live_room_navigation_controller.dart';
import '../controllers/live_room_presence_controller.dart';
import '../controllers/live_room_seat_controller.dart';
import '../controllers/live_room_settings_controller.dart';
import '../controllers/live_room_state_controller.dart';
import '../controllers/live_room_users_controller.dart';
import '../controllers/live_room_vibesync_controller.dart';
import '../live_room_models.dart';
import '../live_room_restore_state.dart';
import '../widgets/room_theme.dart';
import '../widgets/vibesync_room_module.dart';

typedef LiveRoomContextGetter = BuildContext Function();
typedef LiveRoomMountedGetter = bool Function();

class LiveRoomControllerConfig {
  const LiveRoomControllerConfig({
    required this.roomName,
    required this.roomId,
    required this.language,
    required this.modeTitle,
    required this.onlineCount,
    this.initialBackgroundTheme,
    this.restoreState,
  });

  final String roomName;
  final String roomId;
  final String language;
  final String modeTitle;
  final int onlineCount;
  final RoomBackgroundTheme? initialBackgroundTheme;
  final LiveRoomRestoreState? restoreState;
}

class PendingSeatInvite {
  const PendingSeatInvite({
    required this.inviterName,
    required this.invitedUser,
    required this.seatIndex,
  });

  final String inviterName;
  final SeatUser invitedUser;
  final int seatIndex;
}

const SeatUser roomIdentityFallback = SeatUser(
  id: 'user_pending',
  name: 'Vibe User',
  roleLabel: 'Guest',
  familyName: '',
  familyLevel: 'bronze',
  relationshipText: '',
  vipLevel: 0,
  svipLevel: 0,
  sendingLevel: 0,
  receivingLevel: 0,
  sentExp: 0,
  receivedExp: 0,
  medals: <String>[],
  avatarColors: <Color>[Color(0xFF12C7B7), Color(0xFF6D5DF6)],
  isCurrentUser: true,
);

class LiveRoomControllerBundle {
  LiveRoomControllerBundle({
    required this.config,
    required LiveRoomContextGetter contextGetter,
    required LiveRoomMountedGetter mountedGetter,
  }) : _contextGetter = contextGetter,
       _mountedGetter = mountedGetter;

  final LiveRoomControllerConfig config;
  final LiveRoomContextGetter _contextGetter;
  final LiveRoomMountedGetter _mountedGetter;

  late final LiveRoomMentionTextController messageController;
  late final TextEditingController announcementController;
  late final FocusNode messageFocusNode;
  late final LiveRoomStateController roomStateController;
  late final LiveRoomSeatController seatController;
  late final LiveRoomMessageController roomMessageController;
  late final LiveRoomModerationController moderationController;
  late final LiveRoomPresenceController presenceController;

  final LiveRoomUsersController usersController =
      const LiveRoomUsersController();
  final LiveRoomSettingsController settingsController =
      const LiveRoomSettingsController();
  final LiveRoomVibeSyncController vibeSyncController =
      const LiveRoomVibeSyncController();
  final LiveRoomNavigationController navigationController =
      const LiveRoomNavigationController();
  final ChatModerationApiService chatModerationApi =
      const ChatModerationApiService();
  final ValueNotifier<int> roomRevision = ValueNotifier<int>(0);
  final ValueNotifier<int> giftRevision = ValueNotifier<int>(0);

  LiveRoomGiftController? giftControllerInstance;
  String? preCricketLayoutId;
  RoomBackgroundTheme? preCricketBackgroundTheme;
  PendingSeatInvite? pendingSeatInvite;

  Timer? seatInviteAutoHideTimer;
  Timer? hostSeatOneTimer;
  Timer? hostSeatOneRetryTimer;
  VoidCallback? seatInviteListener;
  VoidCallback? roomMembershipListener;
  VoidCallback? roomMemberRequestListener;
  VoidCallback? roomStateChangedListener;
  VoidCallback? syncLuckyPacketBeforeRoomRevision;

  bool disposed = false;

  BuildContext get context => _contextGetter();
  bool get mounted => _mountedGetter();

  SeatUser get currentUser {
    return LiveRoomMediaSignalingService.instance.activeLoggedInSeatUser ??
        roomIdentityFallback;
  }

  String get roomName => roomStateController.roomName;
  String get roomId => roomStateController.roomId;
  RoomPrivacyMode get privacyMode => roomStateController.privacyMode;
  bool get roomImagesEnabled => roomStateController.roomImagesEnabled;
  bool get guestMessagesEnabled => roomStateController.guestMessagesEnabled;
  bool get minimized => roomStateController.minimized;
  bool get allowRoomPop => roomStateController.allowRoomPop;
  bool get applyOnlyModeEnabled => roomStateController.applyOnlyModeEnabled;
  int get inboxUnreadCount => roomStateController.inboxUnreadCount;
  VibeSyncRoomState get vibeSyncState => roomStateController.vibeSyncState;
  Offset get bubbleOffset => roomStateController.bubbleOffset;
  RoomBackgroundTheme get selectedBackgroundTheme =>
      roomStateController.selectedBackgroundTheme;

  List<SeatUser> get roomUsers => seatController.roomUsers;

  List<SeatUser> get pendingRoomMemberRequests {
    return LiveRoomMemberRequestService.instance.pendingRequests.value;
  }

  bool get currentUserIsMember {
    if (viewerCanManageRoom) return true;
    return LiveRoomMembershipService.isRoomMember(
      roomId: roomId,
      userId: currentUser.id,
    );
  }

  bool get joinRequestPending {
    return LiveRoomMembershipService.isPending(
      roomId: roomId,
      userId: currentUser.id,
    );
  }

  List<SeatUser> get allRoomUsers {
    return usersController.buildAllRoomUsers(
      seatedUsers: roomUsers,
      fallbackRoomUsers: mockRoomUsers,
      inviteUsers: mockInviteUsers,
      isUserRemoved: moderationController.isLocallyKickedOut,
    );
  }

  List<SeatUser> get roomAdmins =>
      usersController.buildRoomAdmins(allRoomUsers);

  List<SeatUser> get availableAdminUsers {
    return usersController.buildAvailableAdminUsers(allRoomUsers);
  }

  bool get viewerCanManageRoom => currentUser.isHost || currentUser.isRoomAdmin;
  bool get viewerCanManageAdmins => currentUser.isHost;

  int get safeOnlineCount {
    return moderationController.safeOnlineCount(
      backendOnlineCount: config.onlineCount,
      visibleRoomUsersCount: allRoomUsers.length,
    );
  }

  bool get currentUserIsSeated => seatController.currentUserIsSeated;

  void initialize({
    required VoidCallback onRoomStateChanged,
    required VoidCallback onSeatInviteUpdate,
    required VoidCallback onMembershipChanged,
    required VoidCallback onMemberRequestChanged,
  }) {
    final restoreState = config.restoreState;
    final initialStateSnapshot = restoreState?.roomState;
    final initialSeatLayout =
        initialStateSnapshot?.seatLayoutId ??
        restoreState?.seatState.layoutId ??
        '5x2';

    messageController = LiveRoomMentionTextController();
    if (restoreState != null && restoreState.messageDraft.trim().isNotEmpty) {
      messageController.text = restoreState.messageDraft;
    }
    announcementController = TextEditingController();
    messageFocusNode = FocusNode();

    roomStateChangedListener = onRoomStateChanged;
    roomStateController = LiveRoomStateController(
      initialRoomName: config.roomName,
      initialRoomId: config.roomId,
      initialModeTitle: config.modeTitle,
      initialBackgroundTheme: config.initialBackgroundTheme,
      initialStateSnapshot: initialStateSnapshot,
      preserveInitialBackgroundOnFirstLoad:
          config.initialBackgroundTheme != null,
      initialInboxUnreadCount: 0,
    )..addListener(roomStateChangedListener!);

    moderationController = LiveRoomModerationController(
      currentUser: currentUser,
    );

    roomMessageController = LiveRoomMessageController(
      currentUser: currentUser,
      restoreState: restoreState?.messageState,
      onChanged: () => notifyRoomChanged(),
    );

    seatController = LiveRoomSeatController(
      currentUser: currentUser,
      onChanged: () => notifyRoomChanged(),
      onToast: (message) {
        if (!mounted) return;
        RoomToast.show(context, message);
      },
    )..initialize(initialSeatLayout, restoreState: restoreState?.seatState);

    presenceController = LiveRoomPresenceController();

    seatInviteListener = onSeatInviteUpdate;
    LiveRoomMediaSignalingService.instance.seatInvite.addListener(
      seatInviteListener!,
    );

    roomMembershipListener = onMembershipChanged;
    LiveRoomMembershipService.snapshots.addListener(roomMembershipListener!);

    roomMemberRequestListener = onMemberRequestChanged;
    LiveRoomMemberRequestService.instance.pendingRequests.addListener(
      roomMemberRequestListener!,
    );

    LiveRoomMemberRequestService.instance.startRoom(
      roomId: roomId,
      currentUser: currentUser,
    );

    unawaited(roomStateController.loadPersistedRoomSettings());
  }

  void dispose() {
    disposed = true;
    seatInviteAutoHideTimer?.cancel();
    hostSeatOneTimer?.cancel();
    hostSeatOneRetryTimer?.cancel();

    final inviteListener = seatInviteListener;
    if (inviteListener != null) {
      LiveRoomMediaSignalingService.instance.seatInvite.removeListener(
        inviteListener,
      );
    }

    final membershipListener = roomMembershipListener;
    if (membershipListener != null) {
      LiveRoomMembershipService.snapshots.removeListener(membershipListener);
    }

    final memberRequestListener = roomMemberRequestListener;
    if (memberRequestListener != null) {
      LiveRoomMemberRequestService.instance.pendingRequests.removeListener(
        memberRequestListener,
      );
    }

    final stateListener = roomStateChangedListener;
    if (stateListener != null)
      roomStateController.removeListener(stateListener);

    giftControllerInstance?.dispose();
    messageController.dispose();
    announcementController.dispose();
    messageFocusNode.dispose();
    seatController.dispose();
    moderationController.dispose();
    presenceController.leave();
    presenceController.dispose();
    roomStateController.dispose();
    roomRevision.dispose();
    giftRevision.dispose();
  }

  void setRoomState(VoidCallback callback) {
    if (!mounted || disposed) return;
    callback();
    notifyRoomChanged();
  }

  void notifyRoomChanged({bool syncLuckyPacket = true}) {
    if (!mounted || disposed) return;
    if (syncLuckyPacket) syncLuckyPacketBeforeRoomRevision?.call();
    roomRevision.value++;
  }

  void notifyGiftChanged() {
    if (!mounted || disposed) return;
    giftRevision.value++;
  }
}
