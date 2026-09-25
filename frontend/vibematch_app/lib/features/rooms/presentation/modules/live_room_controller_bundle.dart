import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../room_session/data/room_session_repository.dart';
import '../../../../room_session/domain/room_session_state.dart';
import '../../data/room_session_legacy_adapter.dart';
import '../../data/chat_moderation_api_service.dart';
import '../../data/live_room_media_signaling_service.dart';
import '../../data/live_room_presence_repository.dart';
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
    required this.roomSessionRepository,
    required LiveRoomContextGetter contextGetter,
    required LiveRoomMountedGetter mountedGetter,
  }) : _contextGetter = contextGetter,
       _mountedGetter = mountedGetter,
       _backendOnlineCount = config.onlineCount;

  final LiveRoomControllerConfig config;
  final RoomSessionRepository roomSessionRepository;
  final LiveRoomContextGetter _contextGetter;
  final LiveRoomMountedGetter _mountedGetter;
  int _backendOnlineCount;

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
    final raw = roomSessionRepository
        .currentState.activities['pending_room_member_requests'];
    if (raw is! List) return const <SeatUser>[];
    return raw
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .map(LiveRoomPresenceSnapshot.participantToSeatUser)
        .toList(growable: false);
  }

  bool get currentUserIsMember {
    if (viewerCanManageRoom) return true;
    final aliases = _identityAliases(currentUser.id);
    final state = roomSessionRepository.currentState;
    for (final entry in state.membershipRoster.values) {
      if (_matchesIdentity(
            aliases,
            backendUserId: entry.backendUserId,
            publicUserId: entry.publicUserId,
          ) &&
          (entry.isMember || entry.isAdmin || entry.isHost)) {
        return true;
      }
    }
    for (final participant in state.presence.values) {
      if (_matchesIdentity(
            aliases,
            backendUserId: participant.backendUserId,
            publicUserId: participant.publicUserId,
          ) &&
          (participant.isMember ||
              participant.isAdmin ||
              participant.isHost)) {
        return true;
      }
    }
    return false;
  }

  bool get joinRequestPending {
    final raw = roomSessionRepository
        .currentState.activities['pending_room_member_requests'];
    if (raw is! List) return false;
    final aliases = _identityAliases(currentUser.id);
    for (final item in raw.whereType<Map>()) {
      final map = item.cast<String, dynamic>();
      final backendId = int.tryParse(
        (map['backend_user_id'] ?? map['user_id'])?.toString() ?? '',
      );
      final publicId =
          int.tryParse(map['public_user_id']?.toString() ?? '');
      if (_matchesIdentity(
        aliases,
        backendUserId: backendId,
        publicUserId: publicId,
      )) {
        return true;
      }
    }
    return false;
  }

  void requestRoomMembership() {
    LiveRoomMediaSignalingService.instance.requestRoomMembership();
  }

  void resolveRoomMembership(
    SeatUser user, {
    required bool approved,
  }) {
    if (approved) {
      LiveRoomMediaSignalingService.instance
          .approveRoomMembership(user.id);
    } else {
      LiveRoomMediaSignalingService.instance
          .rejectRoomMembership(user.id);
    }
  }

  List<SeatUser> get allRoomUsers {
    return usersController.buildAllRoomUsers(
      seatedUsers: roomUsers,
      canonicalUsers: RoomSessionLegacyAdapter.presenceUsers(
        roomSessionRepository.currentState,
      ),
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
      backendOnlineCount: _backendOnlineCount,
      visibleRoomUsersCount: allRoomUsers.length,
    );
  }

  bool get currentUserIsSeated => seatController.currentUserIsSeated;

  void updateBackendOnlineCount(int value) {
    final nextValue = value < 0 ? 0 : value;
    if (_backendOnlineCount == nextValue) return;
    _backendOnlineCount = nextValue;
  }

  void initialize({
    required VoidCallback onRoomStateChanged,
    required VoidCallback onSeatInviteUpdate,
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
      roomSessionRepository: roomSessionRepository,
      onChanged: onRoomStateChanged,
      initialRoomName: config.roomName,
      initialRoomId: config.roomId,
      initialModeTitle: config.modeTitle,
      initialBackgroundTheme: config.initialBackgroundTheme,
      initialStateSnapshot: initialStateSnapshot,
      preserveInitialBackgroundOnFirstLoad:
          config.initialBackgroundTheme != null,
      initialInboxUnreadCount: 0,
    );

    moderationController = LiveRoomModerationController(
      currentUser: currentUser,
    );

    roomMessageController = LiveRoomMessageController(
      roomId: roomId,
      roomSessionRepository: roomSessionRepository,
      currentUser: currentUser,
      restoreState: restoreState?.messageState,
      onChanged: () => notifyRoomChanged(),
    );

    seatController = LiveRoomSeatController(
      currentUser: currentUser,
      roomSessionRepository: roomSessionRepository,
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

    giftControllerInstance?.dispose();
    messageController.dispose();
    announcementController.dispose();
    messageFocusNode.dispose();
    seatController.dispose();
    moderationController.dispose();
    roomMessageController.dispose();
    presenceController.leave();
    presenceController.dispose();
    roomStateController.dispose();
    roomRevision.dispose();
    giftRevision.dispose();
  }

  Set<String> _identityAliases(String rawId) {
    final value = rawId.trim().toLowerCase();
    if (value.isEmpty) return const <String>{};
    final aliases = <String>{value};
    final match = RegExp(r'(?:^|_)user_(\d+)$').firstMatch(value);
    if (match != null) {
      aliases.add(match.group(1)!);
      aliases.add('user_${match.group(1)!}');
    }
    final direct = int.tryParse(value);
    if (direct != null) {
      aliases.add(direct.toString());
      aliases.add('user_$direct');
    }
    return aliases;
  }

  bool _matchesIdentity(
    Set<String> aliases, {
    int? backendUserId,
    int? publicUserId,
  }) {
    if (backendUserId != null && backendUserId > 0) {
      if (aliases.contains(backendUserId.toString()) ||
          aliases.contains('user_$backendUserId')) {
        return true;
      }
    }
    if (publicUserId != null && publicUserId > 0) {
      if (aliases.contains(publicUserId.toString()) ||
          aliases.contains('user_$publicUserId')) {
        return true;
      }
    }
    return false;
  }

  RoomSessionState? _lastAppliedCanonicalState;

  void applyCanonicalRoomState(RoomSessionState state) {
    if (disposed || identical(_lastAppliedCanonicalState, state)) return;
    _lastAppliedCanonicalState = state;
    seatController.applyCanonicalRoomState();
    roomStateController.applyCanonicalRoomState();
    notifyRoomChanged(syncLuckyPacket: false);
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
