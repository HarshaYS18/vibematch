import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../social/widgets/friends_invite_sheet.dart';
import '../data/chat_moderation_api_service.dart';
import '../data/live_room_media_signaling_service.dart';
import '../data/live_room_member_request_service.dart';
import '../data/live_room_membership_service.dart';
import '../data/room_api_service.dart';
import '../data/room_moderation_repository.dart';
import 'controllers/live_room_gift_controller.dart';
import 'controllers/live_room_message_controller.dart';
import 'controllers/live_room_mention_text_controller.dart';
import 'controllers/live_room_moderation_controller.dart';
import 'controllers/live_room_navigation_controller.dart';
import 'controllers/live_room_presence_controller.dart';
import 'controllers/live_room_profile_navigator.dart';
import 'controllers/live_room_seat_controller.dart';
import 'controllers/live_room_sheet_controller.dart';
import 'controllers/live_room_settings_controller.dart';
import 'controllers/live_room_state_controller.dart';
import 'controllers/live_room_users_controller.dart';
import 'controllers/live_room_vibesync_controller.dart';
import 'live_room_models.dart';
import 'live_room_restore_state.dart';
import 'modules/cricket_room_mode_registry.dart';
import 'modules/cricket_room_mode_signal.dart';
import 'modules/cricket_stumps_flow_module.dart';
import 'modules/live_room_emoji_actions_module.dart';
import 'modules/live_room_games_actions_module.dart';
import 'modules/live_room_gift_actions_module.dart';
import 'modules/live_room_inbox_actions_module.dart';
import 'modules/live_room_leave_actions_module.dart';
import 'modules/live_room_message_actions_module.dart';
import 'widgets/cricket_room_backgrounds.dart';
import 'widgets/live_room_announcement_sheet.dart';
import 'widgets/live_room_background_sheet.dart';
import 'widgets/live_room_body.dart';
import 'widgets/live_room_info_sheet.dart';
import 'widgets/live_room_invite_sheet.dart';
import 'widgets/live_room_join_requests_sheet.dart';
import 'widgets/live_room_mini_profile_launcher.dart';
import 'widgets/live_room_minimized_bubble.dart';
import 'widgets/live_room_minimized_overlay_service.dart';
import 'widgets/live_room_overlay_host.dart';
import 'widgets/live_room_privacy_sheet.dart';
import 'widgets/live_room_seat_layout_picker_sheet.dart';
import 'widgets/live_room_settings_sheet_module.dart';
import 'widgets/live_room_shell.dart';
import 'widgets/live_room_users_sheet.dart';
import 'widgets/room_contribution_rankings_sheet.dart';
import 'widgets/room_level_sheet.dart';
import 'widgets/room_seats.dart';
import 'widgets/room_theme.dart';
import 'widgets/vibesync_room_module.dart';

part 'live_room_page_actions.dart';
part 'live_room_page_presence.dart';
part 'live_room_page_sheets.dart';
part 'live_room_page_support.dart';

class LiveRoomPage extends StatefulWidget {
  const LiveRoomPage({
    super.key,
    this.roomName = 'Live Room',
    this.roomId = 'VM000000',
    this.language = 'Telugu',
    this.modeTitle = 'Open',
    this.onlineCount = 1,
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

  @override
  State<LiveRoomPage> createState() => _LiveRoomPageState();
}

class _LiveRoomPageState extends State<LiveRoomPage> {
  late final LiveRoomMentionTextController _messageController;
  late final TextEditingController _announcementController;
  late final FocusNode _messageFocusNode;
  late final LiveRoomStateController _roomStateController;
  late final LiveRoomSeatController _seatController;
  late final LiveRoomMessageController _roomMessageController;
  late final LiveRoomModerationController _moderationController;
  late final LiveRoomPresenceController _presenceController;

  final LiveRoomUsersController _usersController = const LiveRoomUsersController();
  final LiveRoomSettingsController _settingsController = const LiveRoomSettingsController();
  final LiveRoomVibeSyncController _vibeSyncController = const LiveRoomVibeSyncController();
  final LiveRoomNavigationController _navigationController = const LiveRoomNavigationController();
  final ChatModerationApiService _chatModerationApi = const ChatModerationApiService();
  final ValueNotifier<int> _roomRevision = ValueNotifier<int>(0);
  final ValueNotifier<int> _giftRevision = ValueNotifier<int>(0);

  LiveRoomGiftController? _giftControllerInstance;
  String? _preCricketLayoutId;
  RoomBackgroundTheme? _preCricketBackgroundTheme;

  _PendingSeatInvite? _pendingSeatInvite;
  Timer? _seatInviteAutoHideTimer;
  Timer? _hostSeatOneTimer;
  Timer? _hostSeatOneRetryTimer;
  VoidCallback? _seatInviteListener;
  VoidCallback? _roomMembershipListener;
  VoidCallback? _roomMemberRequestListener;

  SeatUser get _currentUser {
    return LiveRoomMediaSignalingService.instance.activeLoggedInSeatUser ?? _roomIdentityFallback;
  }

  String get _roomName => _roomStateController.roomName;
  String get _roomId => _roomStateController.roomId;
  RoomPrivacyMode get _privacyMode => _roomStateController.privacyMode;
  bool get _roomImagesEnabled => _roomStateController.roomImagesEnabled;
  bool get _guestMessagesEnabled => _roomStateController.guestMessagesEnabled;
  bool get _minimized => _roomStateController.minimized;
  bool get _allowRoomPop => _roomStateController.allowRoomPop;
  bool get _applyOnlyModeEnabled => _roomStateController.applyOnlyModeEnabled;
  int get _inboxUnreadCount => _roomStateController.inboxUnreadCount;
  VibeSyncRoomState get _vibeSyncState => _roomStateController.vibeSyncState;
  Offset get _bubbleOffset => _roomStateController.bubbleOffset;
  RoomBackgroundTheme get _selectedBackgroundTheme => _roomStateController.selectedBackgroundTheme;

  List<SeatUser> get _roomUsers => _seatController.roomUsers;

  List<SeatUser> get _pendingRoomMemberRequests {
    return LiveRoomMemberRequestService.instance.pendingRequests.value;
  }

  bool get _currentUserIsMember {
    if (_viewerCanManageRoom) return true;
    return LiveRoomMembershipService.isRoomMember(roomId: _roomId, userId: _currentUser.id);
  }

  bool get _joinRequestPending {
    return LiveRoomMembershipService.isPending(roomId: _roomId, userId: _currentUser.id);
  }

  List<SeatUser> get _allRoomUsers {
    return _usersController.buildAllRoomUsers(
      seatedUsers: _roomUsers,
      fallbackRoomUsers: mockRoomUsers,
      inviteUsers: mockInviteUsers,
      isUserRemoved: _moderationController.isLocallyKickedOut,
    );
  }

  List<SeatUser> get _roomAdmins => _usersController.buildRoomAdmins(_allRoomUsers);

  List<SeatUser> get _availableAdminUsers => _usersController.buildAvailableAdminUsers(_allRoomUsers);

  bool get _viewerCanManageRoom => _currentUser.isHost || _currentUser.isRoomAdmin;

  bool get _viewerCanManageAdmins => _currentUser.isHost;

  int get _safeOnlineCount {
    return _moderationController.safeOnlineCount(
      backendOnlineCount: widget.onlineCount,
      visibleRoomUsersCount: _allRoomUsers.length,
    );
  }

  bool get _currentUserIsSeated => _seatController.currentUserIsSeated;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();

    final restoreState = widget.restoreState;
    final initialStateSnapshot = restoreState?.roomState;
    final initialSeatLayout = initialStateSnapshot?.seatLayoutId ?? restoreState?.seatState.layoutId ?? '5x2';

    _messageController = LiveRoomMentionTextController();
    if (restoreState != null && restoreState.messageDraft.trim().isNotEmpty) {
      _messageController.text = restoreState.messageDraft;
    }
    _announcementController = TextEditingController();
    _messageFocusNode = FocusNode();

    _roomStateController = LiveRoomStateController(
      initialRoomName: widget.roomName,
      initialRoomId: widget.roomId,
      initialModeTitle: widget.modeTitle,
      initialBackgroundTheme: widget.initialBackgroundTheme,
      initialStateSnapshot: initialStateSnapshot,
      preserveInitialBackgroundOnFirstLoad: widget.initialBackgroundTheme != null,
      initialInboxUnreadCount: 0,
    )..addListener(_onRoomStateChanged);

    _moderationController = LiveRoomModerationController(currentUser: _currentUser);

    _roomMessageController = LiveRoomMessageController(
      currentUser: _currentUser,
      restoreState: restoreState?.messageState,
      onChanged: () => _notifyRoomChanged(),
    );

    _seatController = LiveRoomSeatController(
      currentUser: _currentUser,
      onChanged: () => _notifyRoomChanged(),
      onToast: (message) {
        if (!mounted) return;
        RoomToast.show(context, message);
      },
    )..initialize(initialSeatLayout, restoreState: restoreState?.seatState);

    _presenceController = LiveRoomPresenceController();

    _seatInviteListener = _handleSeatInviteUpdate;
    LiveRoomMediaSignalingService.instance.seatInvite.addListener(_seatInviteListener!);

    _roomMembershipListener = () => _notifyRoomChanged();
    LiveRoomMembershipService.snapshots.addListener(_roomMembershipListener!);

    _roomMemberRequestListener = () => _notifyRoomChanged();
    LiveRoomMemberRequestService.instance.pendingRequests.addListener(_roomMemberRequestListener!);

    LiveRoomMemberRequestService.instance.startRoom(roomId: _roomId, currentUser: _currentUser);

    _startRoomPresence();
    _syncPresenceRoomDetails();

    unawaited(_roomStateController.loadPersistedRoomSettings());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _autoOccupySeatOneForHostOrAdmin();
      _handleSeatInviteUpdate();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _seatInviteAutoHideTimer?.cancel();
    _hostSeatOneTimer?.cancel();
    _hostSeatOneRetryTimer?.cancel();

    final seatInviteListener = _seatInviteListener;
    if (seatInviteListener != null) {
      LiveRoomMediaSignalingService.instance.seatInvite.removeListener(seatInviteListener);
    }

    final membershipListener = _roomMembershipListener;
    if (membershipListener != null) {
      LiveRoomMembershipService.snapshots.removeListener(membershipListener);
    }

    final memberRequestListener = _roomMemberRequestListener;
    if (memberRequestListener != null) {
      LiveRoomMemberRequestService.instance.pendingRequests.removeListener(memberRequestListener);
    }

    LiveRoomMemberRequestService.instance.stop();
    _giftControllerInstance?.dispose();
    CricketRoomModeRegistry.disposeRoom(_roomId);

    _roomStateController.removeListener(_onRoomStateChanged);
    _messageController.dispose();
    _announcementController.dispose();
    _messageFocusNode.dispose();
    _seatController.dispose();
    _moderationController.dispose();
    _presenceController.leave();
    _presenceController.dispose();
    _roomStateController.dispose();
    _roomRevision.dispose();
    _giftRevision.dispose();
    super.dispose();
  }

  LiveRoomGiftController _createGiftController() {
    return LiveRoomGiftController(
      currentUser: _currentUser,
      onChanged: _notifyGiftChanged,
      onFinalGiftMessage: (entry) {
        if (!mounted) return;
        _roomMessageController.insertEntry(entry);
      },
      onToast: (message) {
        if (!mounted) return;
        RoomToast.show(context, message);
      },
    );
  }

  void _setRoomState(VoidCallback callback) {
    if (!mounted || _disposed) return;
    callback();
    _notifyRoomChanged();
  }

  void _notifyRoomChanged({bool syncLuckyPacket = true}) {
    if (!mounted || _disposed) return;
    if (syncLuckyPacket) _bindLuckyPacketBusIfReady();
    _roomRevision.value++;
  }

  void _notifyGiftChanged() {
    if (!mounted || _disposed) return;
    _giftRevision.value++;
  }

  void _bindLuckyPacketBusIfReady() {
    final controller = _giftControllerInstance;
    if (controller == null) return;
    controller.ensureDefaultReceiver(_roomUsers);
    LuckyPacketRoomBus.bind(controller: controller, roomUsers: _allRoomUsers);
  }

  void _capturePreCricketRoomState() {
    if (CricketRoomModeSignal.isActive(_roomId)) return;
    _preCricketLayoutId ??= _seatController.layoutId;
    if (_preCricketBackgroundTheme == null && !isCricketRoomBackground(_selectedBackgroundTheme)) {
      _preCricketBackgroundTheme = _selectedBackgroundTheme;
    }
  }

  RoomBackgroundTheme _normalBackgroundAfterCricket() {
    final savedBackground = _preCricketBackgroundTheme;
    if (savedBackground == null || isCricketRoomBackground(savedBackground)) {
      return defaultRoomBackgroundTheme;
    }
    return savedBackground;
  }

  void _handleCricketStartNewMatch() {
    if (!CricketRoomModeSignal.isActive(_roomId)) return;
    _clearRoomFocus();
    CricketStumpsFlowModule.open(
      context: context,
      roomId: _roomId,
      roomName: _roomName,
      canManage: true,
      previousBackground: _normalBackgroundAfterCricket(),
      onBackgroundChanged: _roomStateController.setSelectedBackgroundTheme,
      onSystemMessage: _insertSystemMessage,
    );
  }

  void _handleCricketEndMatch() {
    final restoreLayout = _preCricketLayoutId ?? _roomStateController.seatLayoutId;
    final restoreBackground = _normalBackgroundAfterCricket();

    LiveRoomMediaSignalingService.instance.endCricketMode(_roomId);
    CricketRoomModeRegistry.disposeRoom(_roomId);

    _seatController.changeLayout(restoreLayout);
    _roomStateController.setSeatLayoutId(restoreLayout);
    _roomStateController.setSelectedBackgroundTheme(restoreBackground);
    LiveRoomMediaSignalingService.instance.setRoomBackgroundTheme(restoreBackground.id);

    _preCricketLayoutId = null;
    _preCricketBackgroundTheme = null;

    RoomToast.show(context, 'Cricket Mode ended');
    _insertSystemMessage('Cricket Mode ended by ${_currentUser.name}. Chat room restored.');
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _roomRevision,
      builder: (context, value, child) => _buildRoomRoute(context),
    );
  }

  Widget _buildRoomRoute(BuildContext context) {
    if (_minimized) {
      return LiveRoomShell(
        canPop: _allowRoomPop,
        onPopInvokedWithResult: _handleRoomPop,
        backgroundTheme: _selectedBackgroundTheme,
        onDismissOverlays: () {},
        children: [
          LiveRoomMinimizedBubble(
            offset: _bubbleOffset,
            onRestore: () {
              dismissRoomSeatActionPill();
              _clearRoomFocus();
              _roomStateController.setBubbleOffset(_bubbleOffset);
              _roomStateController.setMinimized(false);
            },
            onDrag: (details) {
              _roomStateController.moveBubble(
                delta: details.delta,
                screenSize: MediaQuery.sizeOf(context),
              );
            },
          ),
        ],
      );
    }

    return LiveRoomShell(
      canPop: _allowRoomPop,
      onPopInvokedWithResult: _handleRoomPop,
      backgroundTheme: _selectedBackgroundTheme,
      onDismissOverlays: _dismissRoomOverlays,
      children: [
        LiveRoomBody(
          roomName: _roomName,
          roomId: _roomId,
          privacyMode: _privacyMode,
          onlineCount: _safeOnlineCount,
          seats: _seatController.seats,
          layoutId: _seatController.layoutId,
          selectedSeatIndex: _seatController.selectedSeatIndex,
          canManageSeats: _viewerCanManageRoom,
          canManageAdmins: _viewerCanManageAdmins,
          canEditRoomName: _viewerCanManageAdmins,
          canManageAnnouncement: _viewerCanManageAdmins,
          applyOnlyModeEnabled: _applyOnlyModeEnabled,
          currentUserIsMember: _currentUserIsMember,
          joinRequestPending: _joinRequestPending,
          admins: _roomAdmins,
          availableAdminUsers: _availableAdminUsers,
          onAddAdmin: _addRoomAdminFromInfo,
          onRemoveAdmin: _removeRoomAdminFromInfo,
          onRemoveRoomMember: _removeRoomMemberFromInfo,
          messages: _roomMessageController.messages,
          canManageSeatApplications: _viewerCanManageRoom,
          messageController: _messageController,
          messageFocusNode: _messageFocusNode,
          micMuted: _seatController.micMuted,
          showMicButton: _currentUserIsSeated,
          inboxUnreadCount: _inboxUnreadCount,
          imagesEnabled: _roomImagesEnabled,
          onBack: _openLeaveSheet,
          onJoinTap: _handleJoinRoom,
          onShare: _openRoomShareSheet,
          onAnnouncement: _openAnnouncementSheet,
          onEditRoomName: _openEditRoomNameSheet,
          onSettings: _openSettingsSheet,
          onUsersTap: _openRoomUsersSheet,
          onRoomRankingsTap: _openRoomRankingsSheet,
          onRoomLevelTap: _openRoomLevelPage,
          onSeatTap: _onSeatTap,
          onUserTap: _onUserTap,
          onInvite: _inviteSeat,
          onSwitch: _seatController.switchSeat,
          onLock: _seatController.lockSeat,
          onUnlock: _seatController.unlockSeat,
          onApplySeat: _applyForSeat,
          onApproveSeatApplication: _approveSeatApplication,
          onRejectSeatApplication: _rejectSeatApplication,
          onSenderTap: _openMiniProfileFromChat,
          onMentionTap: _openMentionedUserProfile,
          onDismissOverlays: _dismissRoomOverlays,
          onInboxTap: _openInboxPage,
          onEmojiTap: _openEmojiTray,
          onSendTap: _sendMessage,
          onMicTap: _toggleMic,
          onGamesTap: _openGamesSheet,
          onGiftTap: _openGiftPanel,
          onCricketEndMatch: _handleCricketEndMatch,
          onCricketStartNewMatch: _handleCricketStartNewMatch,
        ),
        LiveRoomOverlayHost(
          vibeSyncState: _vibeSyncState,
          onDismissVibeSync: _clearVibeSyncOverlay,
          giftRevision: _giftRevision,
          giftController: _giftControllerInstance,
          roomUsers: _allRoomUsers,
          pendingSeatInviteInviterName: _pendingSeatInvite?.inviterName,
          pendingSeatInviteUser: _pendingSeatInvite?.invitedUser,
          pendingSeatInviteIndex: _pendingSeatInvite?.seatIndex,
          onRejectSeatInvite: _rejectSeatInvite,
          onAcceptSeatInvite: _acceptSeatInvite,
        ),
      ],
    );
  }

  void _handleRoomPop(bool didPop, void result) {
    if (_navigationController.shouldBlockBackAction(allowRoomPop: _allowRoomPop, didPop: didPop)) {
      dismissRoomSeatActionPill();
      _openLeaveSheet();
    }
  }

  void _clearVibeSyncOverlay() {
    _roomStateController.setVibeSyncState(_vibeSyncController.clearOverlay(_vibeSyncState));
  }
}
