import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../social/widgets/friends_invite_sheet.dart';
import '../data/live_room_media_signaling_service.dart';
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
import 'modules/cricket_stumps_flow_module.dart';
import 'modules/live_room_emoji_actions_module.dart';
import 'modules/live_room_games_actions_module.dart';
import 'modules/live_room_gift_actions_module.dart';
import 'modules/live_room_inbox_actions_module.dart';
import 'modules/live_room_leave_actions_module.dart';
import 'modules/live_room_message_actions_module.dart';
import 'modules/room_music_overlay.dart';
import 'widgets/live_room_announcement_sheet.dart';
import 'widgets/live_room_body.dart';
import 'widgets/live_room_gift_overlay.dart';
import 'widgets/live_room_info_sheet.dart';
import 'widgets/live_room_invite_sheet.dart';
import 'widgets/live_room_join_requests_sheet.dart';
import 'widgets/live_room_mini_profile_launcher.dart';
import 'widgets/live_room_minimized_bubble.dart';
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
  });

  final String roomName;
  final String roomId;
  final String language;
  final String modeTitle;
  final int onlineCount;

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

  final LiveRoomUsersController _usersController =
      const LiveRoomUsersController();
  final LiveRoomSettingsController _settingsController =
      const LiveRoomSettingsController();
  final LiveRoomVibeSyncController _vibeSyncController =
      const LiveRoomVibeSyncController();
  final LiveRoomNavigationController _navigationController =
      const LiveRoomNavigationController();
  late final LiveRoomPresenceController _presenceController;

  _PendingSeatInvite? _pendingSeatInvite;
  Timer? _seatInviteAutoHideTimer;
  Timer? _hostSeatOneTimer;
  Timer? _hostSeatOneRetryTimer;
  VoidCallback? _roomMembershipListener;

  SeatUser get _currentUser {
    return LiveRoomMediaSignalingService.instance.activeLoggedInSeatUser ??
        _roomIdentityFallback;
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
  RoomBackgroundTheme get _selectedBackgroundTheme =>
      _roomStateController.selectedBackgroundTheme;

  List<SeatUser> get _roomUsers => _seatController.roomUsers;

  List<SeatUser> get _allRoomUsers {
    final realUsers = <SeatUser>[
      ..._roomUsers,
      if (!_roomUsers.any((user) => user.id == _currentUser.id)) _currentUser,
    ];

    return _usersController.buildAllRoomUsers(
      seatedUsers: _roomUsers,
      fallbackRoomUsers: realUsers,
      inviteUsers: const <SeatUser>[],
      isUserRemoved: _moderationController.isLocallyKickedOut,
    );
  }

  List<SeatUser> get _roomAdmins =>
      _usersController.buildRoomAdmins(_allRoomUsers);
  List<SeatUser> get _availableAdminUsers =>
      _usersController.buildAvailableAdminUsers(_allRoomUsers);
  bool get _viewerCanManageRoom =>
      _currentUser.isHost || _currentUser.isRoomAdmin;

  LiveRoomMembershipStatus get _currentMembershipStatus {
    if (_viewerCanManageRoom) return LiveRoomMembershipStatus.member;
    return LiveRoomMembershipService.statusFor(
      roomId: _roomId,
      userId: _currentUser.id,
    );
  }

  bool get _currentUserIsMember =>
      _currentMembershipStatus == LiveRoomMembershipStatus.member;

  bool get _joinRequestPending =>
      _currentMembershipStatus == LiveRoomMembershipStatus.pending;

  int get _safeOnlineCount {
    return _moderationController.safeOnlineCount(
      backendOnlineCount: widget.onlineCount,
      visibleRoomUsersCount: _roomUsers.length,
    );
  }

  @override
  void initState() {
    super.initState();
    _roomMembershipListener = () {
      if (mounted) setState(() {});
    };
    LiveRoomMembershipService.snapshots.addListener(_roomMembershipListener!);
    final currentUser = _currentUser;

    _messageController = LiveRoomMentionTextController();
    _announcementController = TextEditingController();
    _messageFocusNode = FocusNode();
    _roomStateController = LiveRoomStateController(
      initialRoomName: widget.roomName,
      initialRoomId: widget.roomId,
      initialModeTitle: widget.modeTitle,
    )..addListener(_onRoomStateChanged);
    _presenceController = LiveRoomPresenceController();

    _moderationController = LiveRoomModerationController(
      currentUser: currentUser,
    );

    _roomMessageController = LiveRoomMessageController(
      currentUser: currentUser,
      onChanged: () {
        if (mounted) setState(() {});
      },
    );

    _seatController = LiveRoomSeatController(
      currentUser: currentUser,
      onChanged: () {
        if (mounted) setState(() {});
      },
      onToast: (message) {
        if (!mounted) return;
        RoomToast.show(context, message);
      },
    )..initialize('5x2');

    _giftController = LiveRoomGiftController(
      currentUser: currentUser,
      onChanged: () {
        if (mounted) setState(() {});
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

    if (_roomUsers.isNotEmpty) {
      _giftController.selectedReceiverIds.add(_roomUsers.first.id);
    }

    unawaited(RoomMusicController.instance.attachRoom(widget.roomId));
    unawaited(_roomStateController.loadPersistedRoomSettings());
    _autoOccupySeatOneForHostOrAdmin();
    _startRoomPresence();
  }

  @override
  void dispose() {
    _seatInviteAutoHideTimer?.cancel();
    _hostSeatOneTimer?.cancel();
    _hostSeatOneRetryTimer?.cancel();
    unawaited(_presenceController.leave());
    _presenceController.dispose();
    _seatController.dispose();
    _roomStateController.removeListener(_onRoomStateChanged);
    final membershipListener = _roomMembershipListener;
    if (membershipListener != null) {
      LiveRoomMembershipService.snapshots.removeListener(membershipListener);
    }
    _messageController.dispose();
    _announcementController.dispose();
    _messageFocusNode.dispose();
    _giftController.dispose();
    _moderationController.dispose();
    unawaited(RoomMusicController.instance.stopBecauseControllerExitedRoom());
    _roomStateController.dispose();
    super.dispose();
  }

  void _setRoomState(VoidCallback update) => setState(update);

  void _handleRoomBackInvoked(bool didPop, Object? result) {
    if (didPop) return;
    _openLeaveSheet();
  }

  @override
  Widget build(BuildContext context) {
    if (_minimized) {
      return PopScope<void>(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _roomStateController.setMinimized(false);
        },
        child: Scaffold(
          backgroundColor: RoomColors.pearl,
          body: Stack(
            children: [
              Positioned(
                left: _bubbleOffset.dx,
                top: _bubbleOffset.dy,
                child: LiveRoomMinimizedBubble(
                  offset: _bubbleOffset,
                  onRestore: () => _roomStateController.setMinimized(false),
                  onDrag: (details) {
                    final size = MediaQuery.sizeOf(context);
                    _roomStateController.setBubbleOffset(
                      Offset(
                        (_bubbleOffset.dx + details.delta.dx).clamp(8.0, size.width - 86),
                        (_bubbleOffset.dy + details.delta.dy).clamp(40.0, size.height - 110),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final pendingInvite = _pendingSeatInvite;

    return Stack(
      fit: StackFit.expand,
      children: [
        PopScope<void>(
          canPop: _allowRoomPop,
          onPopInvokedWithResult: _handleRoomBackInvoked,
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: RoomColors.deep,
            body: LiveRoomBody(
              roomName: _roomName,
              roomId: _roomId,
              privacyMode: _privacyMode,
              onlineCount: _safeOnlineCount,
              seats: _seatController.seats,
              layoutId: _seatController.layoutId,
              selectedSeatIndex: _seatController.selectedSeatIndex,
              canManageSeats: _viewerCanManageRoom,
              applyOnlyModeEnabled: _applyOnlyModeEnabled,
              currentUserIsMember: _currentUserIsMember,
              joinRequestPending: _joinRequestPending,
              admins: _roomAdmins,
              availableAdminUsers: _availableAdminUsers,
              onAddAdmin: _addRoomAdminFromInfo,
              onRemoveAdmin: _removeRoomAdminFromInfo,
              messages: _roomMessageController.messages,
              canManageSeatApplications: _viewerCanManageRoom,
              messageController: _messageController,
              messageFocusNode: _messageFocusNode,
              micMuted: _seatController.micMuted,
              inboxUnreadCount: _inboxUnreadCount,
              imagesEnabled: _roomImagesEnabled,
              onBack: _openLeaveSheet,
              onJoinTap: _handleJoinRoom,
              onShare: _openRoomShareSheet,
              onAnnouncement: _openAnnouncementSheet,
              onSettings: _openSettingsSheet,
              onUsersTap: _openRoomUsersSheet,
              onRoomRankingsTap: _openRoomRankingsSheet,
              onRoomLevelTap: _openRoomLevelPage,
              onSeatTap: _onSeatTap,
              onUserTap: _onUserTap,
              onInvite: _inviteSeat,
              onSwitch: _seatController.occupySeat,
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
          ),
        ),
        const LiveRoomRemoteAudioRenderers(),
        LiveRoomGiftOverlay(
          slides: _giftController.giftSlides,
          activeComboSlide: _giftController.activeComboSlide,
          activeLuckyPacket: _giftController.activeLuckyPacket,
          bottomPadding: bottomPadding,
          onComboTap: _giftController.tapGiftCombo,
          onComboButtonTap: () {
            final slide = _giftController.activeComboSlide;
            if (slide != null) _giftController.tapGiftCombo(slide);
          },
          onVideoGiftFinished: _giftController.finishVideoGift,
          onLuckyPacketGetTap: () => _giftController.claimLuckyPacket(_allRoomUsers),
          onLuckyPacketResultsDismiss: _giftController.dismissLuckyPacketResults,
        ),
        if (pendingInvite != null)
          LiveRoomSeatInviteNotification(
            inviterName: pendingInvite.inviterName,
            invitedUser: pendingInvite.invitedUser,
            seatIndex: pendingInvite.seatIndex,
            onReject: _rejectSeatInvite,
            onAccept: _acceptSeatInvite,
          ),
        const RoomMusicOverlayHost(),
      ],
    );
  }
}
