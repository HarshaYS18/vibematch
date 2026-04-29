import 'package:flutter/material.dart';

import '../../inbox/presentation/inbox_page.dart';
import '../data/room_moderation_repository.dart';
import 'controllers/live_room_gift_controller.dart';
import 'controllers/live_room_message_controller.dart';
import 'controllers/live_room_moderation_controller.dart';
import 'controllers/live_room_navigation_controller.dart';
import 'controllers/live_room_seat_controller.dart';
import 'controllers/live_room_sheet_controller.dart';
import 'controllers/live_room_settings_controller.dart';
import 'controllers/live_room_state_controller.dart';
import 'controllers/live_room_users_controller.dart';
import 'controllers/live_room_vibesync_controller.dart';
import 'live_room_models.dart';
import 'widgets/live_room_announcement_sheet.dart';
import 'widgets/live_room_background_sheet.dart';
import 'widgets/live_room_body.dart';
import 'widgets/live_room_emoji_sheet.dart';
import 'widgets/live_room_games_sheet.dart';
import 'widgets/live_room_gift_overlay.dart';
import 'widgets/live_room_gift_panel_sheet.dart';
import 'widgets/live_room_info_sheet.dart';
import 'widgets/live_room_invite_sheet.dart';
import 'widgets/live_room_join_requests_sheet.dart';
import 'widgets/live_room_leave_sheet.dart';
import 'widgets/live_room_mini_profile_launcher.dart';
import 'widgets/live_room_minimized_bubble.dart';
import 'widgets/live_room_minimized_overlay_service.dart';
import 'widgets/live_room_privacy_sheet.dart';
import 'widgets/live_room_seat_layout_picker_sheet.dart';
import 'widgets/live_room_settings_sheet_module.dart';
import 'widgets/live_room_users_sheet.dart';
import 'widgets/room_contribution_rankings_sheet.dart';
import 'widgets/room_seats.dart';
import 'widgets/room_theme.dart';
import 'widgets/vibesync_room_module.dart';

class LiveRoomPage extends StatefulWidget {
  const LiveRoomPage({
    super.key,
    this.roomName = 'Late Night Chill',
    this.roomId = 'VM257808',
    this.language = 'Telugu',
    this.modeTitle = 'Open',
    this.onlineCount = 3,
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
  late final TextEditingController _messageController;
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

  final SeatUser _currentUser = mockRoomUsers.first;

  String get _roomName => _roomStateController.roomName;
  String get _roomId => _roomStateController.roomId;
  RoomPrivacyMode get _privacyMode => _roomStateController.privacyMode;
  bool get _roomImagesEnabled => _roomStateController.roomImagesEnabled;
  bool get _guestMessagesEnabled => _roomStateController.guestMessagesEnabled;
  bool get _minimized => _roomStateController.minimized;
  bool get _allowRoomPop => _roomStateController.allowRoomPop;
  bool get _leaveSheetOpen => _roomStateController.leaveSheetOpen;
  bool get _exitingRoom => _roomStateController.exitingRoom;
  bool get _applyOnlyModeEnabled => _roomStateController.applyOnlyModeEnabled;
  int get _inboxUnreadCount => _roomStateController.inboxUnreadCount;
  VibeSyncRoomState get _vibeSyncState => _roomStateController.vibeSyncState;
  Offset get _bubbleOffset => _roomStateController.bubbleOffset;
  RoomBackgroundTheme get _selectedBackgroundTheme => _roomStateController.selectedBackgroundTheme;

  List<SeatUser> get _roomUsers => _seatController.roomUsers;

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

  int get _safeOnlineCount {
    return _moderationController.safeOnlineCount(
      backendOnlineCount: widget.onlineCount,
      visibleRoomUsersCount: _roomUsers.length,
    );
  }

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _announcementController = TextEditingController();
    _messageFocusNode = FocusNode();
    _roomStateController = LiveRoomStateController(
      initialRoomName: widget.roomName,
      initialRoomId: widget.roomId,
      initialModeTitle: widget.modeTitle,
    )..addListener(_onRoomStateChanged);
    _moderationController = LiveRoomModerationController(currentUser: _currentUser);
    _roomMessageController = LiveRoomMessageController(
      currentUser: _currentUser,
      onChanged: () {
        if (mounted) setState(() {});
      },
    );
    _seatController = LiveRoomSeatController(
      currentUser: _currentUser,
      onChanged: () {
        if (mounted) setState(() {});
      },
      onToast: (message) {
        if (!mounted) return;
        RoomToast.show(context, message);
      },
    )..initialize('5x2');
    _giftController = LiveRoomGiftController(
      currentUser: _currentUser,
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
  }

  @override
  void dispose() {
    _roomStateController.removeListener(_onRoomStateChanged);
    _messageController.dispose();
    _announcementController.dispose();
    _messageFocusNode.dispose();
    _giftController.dispose();
    _moderationController.dispose();
    _roomStateController.dispose();
    super.dispose();
  }

  void _onRoomStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_minimized) {
      return PopScope<void>(
        canPop: _allowRoomPop,
        onPopInvokedWithResult: (didPop, result) {
          if (_navigationController.shouldBlockBackAction(allowRoomPop: _allowRoomPop, didPop: didPop)) {
            dismissRoomSeatActionPill();
            _openLeaveSheet();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Positioned.fill(child: RoomBackground(theme: _selectedBackgroundTheme)),
              LiveRoomMinimizedBubble(
                offset: _bubbleOffset,
                onRestore: () {
                  dismissRoomSeatActionPill();
                  _roomStateController.setMinimized(false);
                },
                onDrag: (details) {
                  dismissRoomSeatActionPill();
                  _roomStateController.setBubbleOffset(_navigationController.nextBubbleOffset(currentOffset: _bubbleOffset, dragDelta: details.delta, screenSize: MediaQuery.sizeOf(context)));
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
        if (_navigationController.shouldBlockBackAction(allowRoomPop: _allowRoomPop, didPop: didPop)) {
          dismissRoomSeatActionPill();
          _openLeaveSheet();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: RoomColors.deep,
        body: Stack(
          children: [
            Positioned.fill(child: RoomBackground(theme: _selectedBackgroundTheme)),
            Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _dismissRoomOverlays, child: const SizedBox.expand())),
            LiveRoomBody(
              roomName: _roomName,
              roomId: _roomId,
              privacyMode: _privacyMode,
              onlineCount: _safeOnlineCount,
              seats: _seatController.seats,
              layoutId: _seatController.layoutId,
              selectedSeatIndex: _seatController.selectedSeatIndex,
              canManageSeats: _viewerCanManageRoom,
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
              onShare: () => RoomToast.show(context, 'Share room invite opened'),
              onAnnouncement: _openAnnouncementSheet,
              onSettings: _openSettingsSheet,
              onUsersTap: _openRoomUsersSheet,
              onRoomRankingsTap: _openRoomRankingsSheet,
              onSeatTap: _onSeatTap,
              onUserTap: _onUserTap,
              onInvite: _inviteSeat,
              onSwitch: _seatController.switchSeat,
              onLock: _seatController.lockSeat,
              onUnlock: _seatController.unlockSeat,
              onApproveSeatApplication: _approveSeatApplication,
              onSenderTap: _openMiniProfileFromChat,
              onDismissOverlays: _dismissRoomOverlays,
              onInboxTap: _openInboxPage,
              onEmojiTap: _openEmojiTray,
              onSendTap: _sendMessage,
              onMicTap: _toggleMic,
              onGamesTap: _openGamesSheet,
              onGiftTap: _openGiftPanel,
            ),
            VibeSyncRoomOverlay(state: _vibeSyncState, onDismiss: _clearVibeSyncOverlay),
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
          ],
        ),
      ),
    );
  }

  void _onSeatTap(int index) {
    final seat = _seatController.seats[index];
    if (seat.locked) {
      if (_viewerCanManageRoom) {
        _seatController.toggleSelectedSeat(index);
      } else {
        RoomToast.show(context, 'This seat is locked');
      }
      return;
    }
    if (seat.user == null && !_viewerCanManageRoom) {
      if (_applyOnlyModeEnabled) {
        _seatController.applyForSeat(index: index, messages: _roomMessageController.messages);
      } else {
        _seatController.occupySeat(index);
      }
      return;
    }
    if (seat.user == null && _viewerCanManageRoom) _seatController.toggleSelectedSeat(index);
  }

  void _onUserTap(int index) {
    final user = _seatController.seats[index].user;
    if (user == null) return;
    _openMiniProfile(user, index);
  }

  void _approveSeatApplication(ChatEntry entry) => _seatController.approveSeatApplication(entry: entry, messages: _roomMessageController.messages, allRoomUsers: _allRoomUsers);
  void _inviteSeat(int index) { _seatController.clearSelectedSeat(); _openSeatInviteSheet(index); }

  void _openSeatInviteSheet(int seatIndex) {
    _clearRoomFocus();
    final inviteUsers = _usersController.buildSeatInviteUsers(allRoomUsers: _allRoomUsers, seatedUsers: _roomUsers);
    LiveRoomSheetController.showTransparentSheet<void>(context: context, builder: (_) => LiveRoomInviteSheet(seatIndex: seatIndex, users: inviteUsers, onInvite: (user) { Navigator.pop(context); RoomToast.show(context, 'Invite sent to ${user.name} for seat ${seatIndex + 1}'); }));
  }

  void _dismissRoomOverlays() { dismissRoomSeatActionPill(); _clearRoomFocus(); }
  void _insertSystemMessage(String message) => _roomMessageController.insertSystemMessage(message);
  void _clearRoomFocus() { _messageFocusNode.unfocus(); FocusManager.instance.primaryFocus?.unfocus(); }
  void _toggleMic() { _clearRoomFocus(); _seatController.toggleMic(); }
  void _handleJoinRoom() { _clearRoomFocus(); _roomMessageController.requestJoin(); _openInfoSheet('Join request sent', 'Your request to become a member of $_roomName has been sent to the room owner/admins.'); }

  void _openRoomUsersSheet() {
    LiveRoomSheetController.showTransparentSheet<void>(context: context, isScrollControlled: true, builder: (_) => LiveRoomUsersSheet(users: _roomUsers, onUserTap: (user) { Navigator.pop(context); Future<void>.delayed(const Duration(milliseconds: 80), () { if (mounted) _openMiniProfileForUser(user); }); }));
  }

  void _openRoomRankingsSheet() {
    LiveRoomSheetController.showTransparentSheet<void>(context: context, isScrollControlled: true, builder: (_) => RoomContributionRankingsSheet(roomName: _roomName, users: _allRoomUsers, onUserTap: (user) { Navigator.pop(context); Future<void>.delayed(const Duration(milliseconds: 80), () { if (mounted) _openMiniProfileForUser(user); }); }));
  }

  void _sendMessage() { final text = _messageController.text.trim(); if (text.isEmpty) return; _roomMessageController.sendMessage(text); _messageController.clear(); }

  void _openMiniProfileFromChat(ChatEntry entry) { if (entry.senderId == null || entry.senderId == 'system') return; _openMiniProfileForUser(_usersController.resolveUserFromChatEntry(entry: entry, allRoomUsers: _allRoomUsers)); }
  void _openMiniProfileForUser(SeatUser user) { final liveUser = _allRoomUsers.firstWhere((item) => item.id == user.id, orElse: () => user); final seatIndex = _seatController.seats.indexWhere((seat) => seat.user?.id == liveUser.id); _openMiniProfile(liveUser, seatIndex); }

  void _openMiniProfile(SeatUser user, int seatIndex) {
    _clearRoomFocus();
    LiveRoomMiniProfileLauncher.open(
      context: context,
      user: user,
      seatIndex: seatIndex,
      currentUser: _currentUser,
      canModerate: _viewerCanManageRoom,
      allRoomUsers: _allRoomUsers,
      privacyMode: _privacyMode,
      roomName: _roomName,
      roomId: _roomId,
      onMentionTap: _mentionUser,
      onSetAdminTap: _setUserAsAdmin,
      onRemoveAdminTap: _removeUserAsAdmin,
      onReportTap: _openReportForUser,
      onKickOutDurationSelected: _canKickOutUser(user) ? (duration) => _kickOutUser(user: user, duration: duration) : null,
      onLeaveAndLock: (targetSeatIndex) { Navigator.pop(context); _seatController.leaveAndLockSeat(targetSeatIndex); },
      onSelfMuteToggle: (userId) { Navigator.pop(context); _seatController.toggleSelfMute(userId); },
      onAdminMuteToggle: (userId) { Navigator.pop(context); _seatController.toggleAdminMute(userId); },
      onGiftTap: (userId) { Navigator.pop(context); setState(() { _giftController.selectedReceiverIds..clear()..add(userId); }); _openGiftPanel(); },
    );
  }

  bool _canKickOutUser(SeatUser target) => _moderationController.canKickOutUser(target: target, canManageRoom: _viewerCanManageRoom);

  Future<void> _kickOutUser({required SeatUser user, required RoomKickoutDuration duration}) async {
    final result = await _moderationController.kickOutUser(roomId: _roomId, target: user, duration: duration, canManageRoom: _viewerCanManageRoom);
    if (!mounted) return;
    final systemMessage = result.systemMessage;
    if (systemMessage != null) _insertSystemMessage(systemMessage);
    final removedUserId = result.removedUserId;
    if (removedUserId != null) _seatController.removeUserFromRoom(removedUserId);
    final toastMessage = result.toastMessage;
    if (toastMessage != null) RoomToast.show(context, toastMessage);
  }

  void _mentionUser(SeatUser user) { Navigator.pop(context); final mention = '@${user.name} '; final current = _messageController.text; _messageController.text = current.endsWith(' ') || current.isEmpty ? '$current$mention' : '$current $mention'; _messageController.selection = TextSelection.collapsed(offset: _messageController.text.length); _messageFocusNode.requestFocus(); }
  void _setUserAsAdmin(String userId) { Navigator.pop(context); _seatController.setUserAsAdmin(userId); _clearRoomFocus(); }
  void _removeUserAsAdmin(String userId) { Navigator.pop(context); _seatController.removeUserAsAdmin(userId); _clearRoomFocus(); }
  void _addRoomAdminFromInfo(SeatUser user) { _seatController.setUserAsAdmin(user.id); _clearRoomFocus(); }
  void _removeRoomAdminFromInfo(SeatUser user) { _seatController.removeUserAsAdmin(user.id); _clearRoomFocus(); }
  void _openReportForUser(SeatUser user) { Navigator.pop(context); _openInfoSheet('Report submitted', '${user.name} has been sent to the room safety review queue.'); }

  void _openGiftPanel() {
    _clearRoomFocus();
    _giftController.ensureDefaultReceiver(_roomUsers);
    LiveRoomSheetController.showTransparentSheet<void>(context: context, isScrollControlled: true, builder: (_) => LiveRoomGiftPanelSheet(gifts: mockGiftItems, users: _roomUsers, selectedCategory: _giftController.selectedCategory, selectedGift: _giftController.selectedGift, selectedReceiverIds: _giftController.selectedReceiverIds, selectedCombo: _giftController.selectedCombo, coinBalance: _giftController.coinBalance, onCategoryChanged: _giftController.selectCategory, onGiftSelected: _giftController.selectGift, onReceiverToggle: (id) => _giftController.toggleReceiver(id, _roomUsers), onComboChanged: _giftController.setCombo, onSend: () { Navigator.pop(context); _giftController.sendGift(_roomUsers); }, onRecharge: () => RoomToast.show(context, 'Wallet / coin recharge opened')));
  }

  void _openInboxPage() { _clearRoomFocus(); _roomStateController.clearInboxUnreadCount(); Navigator.push(context, MaterialPageRoute(builder: (_) => const InboxPage())); }
  void _openInboxPageFromSheet(BuildContext sheetContext) { Navigator.pop(sheetContext); Future<void>.delayed(const Duration(milliseconds: 80), () { if (mounted) _openInboxPage(); }); }
  void _openEmojiTray() { _clearRoomFocus(); LiveRoomSheetController.showTransparentSheet<void>(context: context, builder: (_) => LiveRoomEmojiSheet(onEmojiTap: (emoji) { Navigator.pop(context); RoomToast.show(context, '$emoji reaction will animate over avatar'); })); }

  void _openSettingsSheet() {
    _clearRoomFocus();
    LiveRoomSheetController.showTransparentStatefulSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext, setSheetState) => LiveRoomSettingsSheetModule(
        roomId: _roomId,
        privacyMode: _privacyMode,
        roomImagesEnabled: _roomImagesEnabled,
        guestMessagesEnabled: _guestMessagesEnabled,
        applyOnlyModeEnabled: _applyOnlyModeEnabled,
        joinRequestCount: _roomMessageController.joinRequestUsers.length,
        onBackgroundTap: _openBackgroundSheet,
        onPrivacyTap: _openPrivacySheet,
        onSeatLayoutTap: _openSeatLayoutSheet,
        onAnnouncementTap: _openAnnouncementSheet,
        onInboxTap: () => _openInboxPageFromSheet(sheetContext),
        onJoinRequestsTap: _openJoinRequestsSheet,
        onVibeSyncTap: () => _openVibeSyncSheetFromSettings(sheetContext),
        onWatchPartyTap: () => _openWatchPartyFromSettings(sheetContext),
        onToggleRoomImages: (value) { _roomStateController.setRoomImagesEnabled(value); setSheetState(() {}); _insertSystemMessage(_settingsController.roomImagesSystemMessage(value)); },
        onToggleGuestMessages: (value) { _roomStateController.setGuestMessagesEnabled(value); setSheetState(() {}); _insertSystemMessage(_settingsController.guestMessagesSystemMessage(value)); },
        onToggleApplyOnlyMode: (value) { _roomStateController.setApplyOnlyModeEnabled(value); setSheetState(() {}); _insertSystemMessage(_settingsController.applyOnlyModeSystemMessage(value)); },
        onCloseRoom: () => _leaveRoomFromSheet(context),
      ),
    );
  }

  void _openWatchPartyFromSettings(BuildContext sheetContext) { Navigator.pop(sheetContext); Future<void>.delayed(const Duration(milliseconds: 80), () { if (mounted) _openInfoSheet('Watch Party', 'Watch Party settings will open here. YouTube link, play/pause/seek sync, and 10-seat watch layout will connect next.'); }); }
  void _openVibeSyncSheetFromSettings(BuildContext sheetContext) { Navigator.pop(sheetContext); Future<void>.delayed(const Duration(milliseconds: 80), () { if (mounted) _openVibeSyncSheet(); }); }

  void _openVibeSyncSheet() {
    _clearRoomFocus();
    LiveRoomSheetController.showTransparentSheet<void>(context: context, isScrollControlled: true, builder: (_) => VibeSyncControlSheet(state: _vibeSyncState, users: _roomUsers, canManage: _viewerCanManageRoom, onPickFirst: (user) { _roomStateController.setVibeSyncState(_vibeSyncController.pickFirstUser(state: _vibeSyncState, user: user)); }, onPickSecond: (user) { _roomStateController.setVibeSyncState(_vibeSyncController.pickSecondUser(state: _vibeSyncState, user: user)); }, onAnnounce: () { Navigator.pop(context); final announcement = _vibeSyncController.announce(_vibeSyncState); if (announcement == null) return; _roomStateController.setVibeSyncState(announcement.state); _insertSystemMessage(announcement.systemMessage); }, onEnd: () { Navigator.pop(context); _roomStateController.setVibeSyncState(_vibeSyncController.end()); _insertSystemMessage(_vibeSyncController.endSystemMessage()); }));
  }

  void _clearVibeSyncOverlay() => _roomStateController.setVibeSyncState(_vibeSyncController.clearOverlay(_vibeSyncState));
  void _openJoinRequestsSheet() { _clearRoomFocus(); LiveRoomSheetController.showTransparentSheet<void>(context: context, builder: (_) => StatefulBuilder(builder: (context, setSheetState) => LiveRoomJoinRequestsSheet(users: _roomMessageController.joinRequestUsers, onApprove: (user) { _resolveJoinRequest(user, approved: true); setSheetState(() {}); }, onReject: (user) { _resolveJoinRequest(user, approved: false); setSheetState(() {}); }))); }
  void _resolveJoinRequest(SeatUser user, {required bool approved}) { _roomMessageController.resolveJoinRequest(user: user, approved: approved, roomName: _roomName); RoomToast.show(context, approved ? '${user.name} approved' : '${user.name} rejected'); }
  void _openPrivacySheet() { _clearRoomFocus(); LiveRoomSheetController.showTransparentSheet<void>(context: context, isScrollControlled: true, builder: (_) => LiveRoomPrivacySheet(currentMode: _privacyMode, onModeChanged: (mode) { _roomStateController.setPrivacyMode(mode); _insertSystemMessage(_settingsController.privacyModeSystemMessage(mode)); })); }
  void _openGamesSheet() { _clearRoomFocus(); LiveRoomSheetController.showTransparentSheet<void>(context: context, builder: (_) => LiveRoomGamesSheet(onCrystalHuntTap: () { Navigator.pop(context); RoomToast.show(context, 'Crystal Hunt opens here'); }, onLudoTap: () { Navigator.pop(context); RoomToast.show(context, 'Ludo opens here'); }, onCarromTap: () { Navigator.pop(context); RoomToast.show(context, 'Carrom opens here'); }, onPkTap: () { Navigator.pop(context); RoomToast.show(context, 'PK game opens here'); })); }
  void _openSeatLayoutSheet() { _clearRoomFocus(); LiveRoomSheetController.showTransparentSheet<void>(context: context, builder: (_) => LiveRoomSeatLayoutPickerSheet(selectedLayout: _seatController.layoutId, onSelected: (layout) { _seatController.changeLayout(layout); Navigator.pop(context); })); }
  void _openBackgroundSheet() { _clearRoomFocus(); LiveRoomSheetController.showTransparentSheet<void>(context: context, isScrollControlled: true, builder: (_) => LiveRoomBackgroundSheet(currentTheme: _selectedBackgroundTheme, onThemeSelected: (theme) { _roomStateController.setSelectedBackgroundTheme(theme); RoomToast.show(context, _settingsController.backgroundAppliedToast(theme)); }, onStoreTap: () => RoomToast.show(context, 'Theme store opened'))); }
  void _openAnnouncementSheet() { _clearRoomFocus(); LiveRoomSheetController.showTransparentSheet<void>(context: context, isScrollControlled: true, builder: (_) => LiveRoomAnnouncementSheet(controller: _announcementController, onSubmit: (message) { Navigator.pop(context); if (message.isNotEmpty) { _insertSystemMessage(message); _announcementController.clear(); } RoomToast.show(context, 'Announcement saved'); })); }

  void _openLeaveSheet() { dismissRoomSeatActionPill(); if (!_navigationController.canOpenLeaveSheet(leaveSheetOpen: _leaveSheetOpen, exitingRoom: _exitingRoom)) return; _roomStateController.setLeaveSheetOpen(true); _clearRoomFocus(); LiveRoomSheetController.showTransparentSheet<void>(context: context, builder: (sheetContext) => LiveRoomLeaveSheet(onStay: () { dismissRoomSeatActionPill(); _stayAndMinimize(sheetContext); }, onLeave: () { dismissRoomSeatActionPill(); _leaveRoomFromSheet(sheetContext); })).whenComplete(() { if (mounted) _roomStateController.setLeaveSheetOpen(false); }); }
  void _stayAndMinimize(BuildContext sheetContext) { dismissRoomSeatActionPill(); final roomNavigator = Navigator.of(context); final rootNavigator = Navigator.of(context, rootNavigator: true); final roomName = _roomName; final roomId = _roomId; final language = widget.language; final modeTitle = widget.modeTitle; final onlineCount = widget.onlineCount; LiveRoomMinimizedOverlayService.show(context: rootNavigator.context, onRestore: () { rootNavigator.push(MaterialPageRoute(builder: (_) => LiveRoomPage(roomName: roomName, roomId: roomId, language: language, modeTitle: modeTitle, onlineCount: onlineCount))); }); Navigator.pop(sheetContext); if (!mounted) return; _roomStateController.setAllowRoomPop(true); WidgetsBinding.instance.addPostFrameCallback((_) { if (!mounted) return; if (roomNavigator.canPop()) { roomNavigator.pop(); } else { _roomStateController.setMinimized(true); } }); }
  void _leaveRoomFromSheet(BuildContext sheetContext) { if (!_navigationController.canExitRoom(exitingRoom: _exitingRoom)) return; _roomStateController.setExitingRoom(true); Navigator.pop(sheetContext); if (!mounted) return; _roomStateController.setAllowRoomPop(true); Future<void>.delayed(const Duration(milliseconds: 80), () { if (mounted) Navigator.maybePop(context); }); }
  void _openInfoSheet(String title, String body) { LiveRoomSheetController.showTransparentSheet<void>(context: context, builder: (_) => LiveRoomInfoSheet(title: title, body: body)); }
}
