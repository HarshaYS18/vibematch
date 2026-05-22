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
import '../data/room_music_controller.dart';
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
import 'modules/cricket_room_mode_signal.dart';
import 'modules/cricket_stumps_flow_module.dart';
import 'modules/live_room_emoji_actions_module.dart';
import 'modules/live_room_games_actions_module.dart';
import 'modules/live_room_gift_actions_module.dart';
import 'modules/live_room_inbox_actions_module.dart';
import 'modules/live_room_leave_actions_module.dart';
import 'modules/live_room_message_actions_module.dart';
import 'modules/room_music_overlay.dart';
import 'widgets/cricket_room_backgrounds.dart';
import 'widgets/live_room_announcement_sheet.dart';
import 'widgets/live_room_background_sheet.dart';
import 'widgets/live_room_body.dart';
import 'widgets/live_room_gift_overlay.dart';
import 'widgets/live_room_info_sheet.dart';
import 'widgets/live_room_invite_sheet.dart';
import 'widgets/live_room_join_requests_sheet.dart';
import 'widgets/live_room_mini_profile_launcher.dart';
import 'widgets/live_room_minimized_bubble.dart';
import 'widgets/live_room_minimized_overlay_service.dart';
import 'widgets/live_room_privacy_sheet.dart';
import 'widgets/live_room_remote_audio_renderers.dart';
import 'widgets/live_room_seat_invite_notification.dart';
import 'widgets/live_room_seat_layout_picker_sheet.dart';
import 'widgets/live_room_settings_sheet_module.dart';
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
  late final LiveRoomGiftController _giftController;
  late final LiveRoomSeatController _seatController;
  late final LiveRoomMessageController _roomMessageController;
  late final LiveRoomModerationController _moderationController;

  final LiveRoomUsersController _usersController = const LiveRoomUsersController();
  final LiveRoomSettingsController _settingsController = const LiveRoomSettingsController();
  final LiveRoomVibeSyncController _vibeSyncController = const LiveRoomVibeSyncController();
  final LiveRoomNavigationController _navigationController = const LiveRoomNavigationController();
  final ChatModerationApiService _chatModerationApi = const ChatModerationApiService();
  late final LiveRoomPresenceController _presenceController;

  bool _giftControllerReady = false;

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
    return LiveRoomMembershipService.isRoomMember(
      roomId: _roomId,
      userId: _currentUser.id,
    );
  }

  bool get _joinRequestPending {
    return LiveRoomMembershipService.isPending(
      roomId: _roomId,
      userId: _currentUser.id,
    );
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

    _moderationController = LiveRoomModerationController(
      currentUser: _currentUser,
    );

    _roomMessageController = LiveRoomMessageController(
      currentUser: _currentUser,
      restoreState: restoreState?.messageState,
      onChanged: () {
        if (mounted) _setRoomState(() {});
      },
    );

    _seatController = LiveRoomSeatController(
      currentUser: _currentUser,
      onChanged: () {
        if (mounted) _setRoomState(() {});
      },
      onToast: (message) {
        if (!mounted) return;
        RoomToast.show(context, message);
      },
    )..initialize(
        initialSeatLayout,
        restoreState: restoreState?.seatState,
      );

    _giftController = LiveRoomGiftController(
      currentUser: _currentUser,
      onChanged: () {
        if (mounted) _setRoomState(() {});
      },
      onFinalGiftMessage: (entry) {
        if (!mounted) return;
        _roomMessageController.insertEntry(entry);
      },
      onToast: (message) {
        if (!mounted) return;
        RoomToast.show(context, message);
      },
    );
    _giftControllerReady = true;

    _presenceController = LiveRoomPresenceController();

    _seatInviteListener = _handleSeatInviteUpdate;
    LiveRoomMediaSignalingService.instance.seatInvite.addListener(_seatInviteListener!);

    _roomMembershipListener = () {
      if (mounted) _setRoomState(() {});
    };
    LiveRoomMembershipService.snapshots.addListener(_roomMembershipListener!);

    _roomMemberRequestListener = () {
      if (mounted) _setRoomState(() {});
    };
    LiveRoomMemberRequestService.instance.pendingRequests.addListener(_roomMemberRequestListener!);

    LiveRoomMemberRequestService.instance.startRoom(
      roomId: _roomId,
      currentUser: _currentUser,
    );

    _startRoomPresence();
    _syncPresenceRoomDetails();

    _giftController.ensureDefaultReceiver(_roomUsers);
    LuckyPacketRoomBus.bind(
      controller: _giftController,
      roomUsers: _allRoomUsers,
    );

    unawaited(_roomStateController.loadPersistedRoomSettings());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _autoOccupySeatOneForHostOrAdmin();
      _handleSeatInviteUpdate();
    });
  }

  @override
  void dispose() {
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
    if (_giftControllerReady) {
      LuckyPacketRoomBus.clearController(_giftController);
    }

    _roomStateController.removeListener(_onRoomStateChanged);
    _messageController.dispose();
    _announcementController.dispose();
    _messageFocusNode.dispose();
    if (_giftControllerReady) {
      _giftController.dispose();
    }
    _seatController.dispose();
    _moderationController.dispose();
    _presenceController.leave();
    _presenceController.dispose();
    _roomStateController.dispose();
    super.dispose();
  }

  void _setRoomState(VoidCallback callback) {
    if (!mounted) return;
    setState(callback);
    if (!_giftControllerReady) return;
    LuckyPacketRoomBus.bind(
      controller: _giftController,
      roomUsers: _allRoomUsers,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_minimized) {
      return PopScope<void>(
        canPop: _allowRoomPop,
        onPopInvokedWithResult: (didPop, result) {
          if (_navigationController.shouldBlockBackAction(
            allowRoomPop: _allowRoomPop,
            didPop: didPop,
          )) {
            dismissRoomSeatActionPill();
            _openLeaveSheet();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Positioned.fill(
                child: RoomBackground(theme: _selectedBackgroundTheme),
              ),
              LiveRoomMinimizedBubble(
                offset: _bubbleOffset,
                onRestore: () {
                  dismissRoomSeatActionPill();
                  _roomStateController.setMinimized(false);
                },
                onDrag: (details) {
                  dismissRoomSeatActionPill();
                  _roomStateController.moveBubble(
                    delta: details.delta,
                    screenSize: MediaQuery.sizeOf(context),
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

    return PopScope<void>(
      canPop: _allowRoomPop,
      onPopInvokedWithResult: (didPop, result) {
        if (_navigationController.shouldBlockBackAction(
          allowRoomPop: _allowRoomPop,
          didPop: didPop,
        )) {
          dismissRoomSeatActionPill();
          _openLeaveSheet();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: RoomColors.deep,
        body: Stack(
          children: [
            Positioned.fill(
              child: RoomBackground(theme: _selectedBackgroundTheme),
            ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _dismissRoomOverlays,
                child: const SizedBox.expand(),
              ),
            ),
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
            ),
            VibeSyncRoomOverlay(
              state: _vibeSyncState,
              onDismiss: _clearVibeSyncOverlay,
            ),
            const LiveRoomRemoteAudioRenderers(),
            const RoomMusicOverlayHost(),
            LiveRoomGiftOverlay(
              slides: _giftController.giftSlides,
              activeComboSlide: _giftController.activeComboSlide,
              bottomPadding: MediaQuery.paddingOf(context).bottom,
              onComboTap: _giftController.tapGiftCombo,
              onVideoGiftFinished: _giftController.finishVideoGift,
              onComboButtonTap: () {
                dismissRoomSeatActionPill();
                final slide = _giftController.activeComboSlide;
                if (slide != null) _giftController.tapGiftCombo(slide);
              },
            ),
            if (_pendingSeatInvite != null)
              LiveRoomSeatInviteNotification(
                inviterName: _pendingSeatInvite!.inviterName,
                invitedUser: _pendingSeatInvite!.invitedUser,
                seatIndex: _pendingSeatInvite!.seatIndex,
                onReject: _rejectSeatInvite,
                onAccept: _acceptSeatInvite,
              ),
          ],
        ),
      ),
    );
  }

  void _clearVibeSyncOverlay() {
    _roomStateController.setVibeSyncState(_vibeSyncController.clearOverlay(_vibeSyncState));
  }
}