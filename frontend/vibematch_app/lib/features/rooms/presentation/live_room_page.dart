import 'package:flutter/material.dart';

import '../../inbox/presentation/inbox_page.dart';
import 'controllers/live_room_gift_controller.dart';
import 'controllers/live_room_message_controller.dart';
import 'controllers/live_room_profile_navigator.dart';
import 'controllers/live_room_seat_controller.dart';
import 'live_room_models.dart';
import 'widgets/live_room_announcement_sheet.dart';
import 'widgets/live_room_body.dart';
import 'widgets/live_room_emoji_sheet.dart';
import 'widgets/live_room_games_sheet.dart';
import 'widgets/live_room_gift_overlay.dart';
import 'widgets/live_room_info_sheet.dart';
import 'widgets/live_room_invite_sheet.dart';
import 'widgets/live_room_join_requests_sheet.dart';
import 'widgets/live_room_leave_sheet.dart';
import 'widgets/live_room_minimized_bubble.dart';
import 'widgets/room_gifts.dart';
import 'widgets/room_profile_sheet.dart';
import 'widgets/room_seats.dart';
import 'widgets/room_settings_sheet.dart';
import 'widgets/room_theme.dart';
import 'widgets/room_user_list_sheet.dart';

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
  late final LiveRoomGiftController _giftController;
  late final LiveRoomSeatController _seatController;
  late final LiveRoomMessageController _roomMessageController;

  late String _roomName;
  late String _roomId;
  late RoomPrivacyMode _privacyMode;

  bool _roomImagesEnabled = true;
  bool _guestMessagesEnabled = true;
  bool _minimized = false;
  bool _allowRoomPop = false;
  bool _leaveSheetOpen = false;
  bool _exitingRoom = false;
  bool _applyOnlyModeEnabled = false;
  int _inboxUnreadCount = 4;

  Offset _bubbleOffset = const Offset(24, 120);
  RoomBackgroundTheme _selectedBackgroundTheme = defaultRoomBackgroundTheme;

  final SeatUser _currentUser = mockRoomUsers.first;

  List<SeatUser> get _roomUsers => _seatController.roomUsers;

  List<SeatUser> get _allRoomUsers {
    final users = <SeatUser>[];
    final ids = <String>{};

    for (final user in mockRoomUsers) {
      if (ids.add(user.id)) users.add(user);
    }
    for (final user in _roomUsers) {
      if (ids.add(user.id)) users.add(user);
    }
    for (final user in mockInviteUsers) {
      if (ids.add(user.id)) users.add(user);
    }

    return users;
  }

  bool get _viewerCanManageRoom =>
      _currentUser.isHost || _currentUser.isRoomAdmin;

  int get _safeOnlineCount {
    return widget.onlineCount > _allRoomUsers.length
        ? widget.onlineCount
        : _allRoomUsers.length;
  }

  @override
  void initState() {
    super.initState();

    _messageController = TextEditingController();
    _announcementController = TextEditingController();
    _messageFocusNode = FocusNode();

    _roomName = widget.roomName;
    _roomId = widget.roomId;
    _privacyMode = privacyModeFromTitle(widget.modeTitle);

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
    _messageController.dispose();
    _announcementController.dispose();
    _messageFocusNode.dispose();
    _giftController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_minimized) {
      return PopScope<void>(
        canPop: _allowRoomPop,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
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
                  setState(() => _minimized = false);
                },
                onDrag: (details) {
                  dismissRoomSeatActionPill();
                  final size = MediaQuery.sizeOf(context);
                  setState(() {
                    _bubbleOffset = Offset(
                      (_bubbleOffset.dx + details.delta.dx).clamp(
                        8.0,
                        size.width - 86,
                      ),
                      (_bubbleOffset.dy + details.delta.dy).clamp(
                        40.0,
                        size.height - 120,
                      ),
                    );
                  });
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
        if (!didPop) {
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
              messages: _roomMessageController.messages,
              canManageSeatApplications: _viewerCanManageRoom,
              messageController: _messageController,
              messageFocusNode: _messageFocusNode,
              micMuted: _seatController.micMuted,
              inboxUnreadCount: _inboxUnreadCount,
              imagesEnabled: _roomImagesEnabled,
              onBack: _openLeaveSheet,
              onJoinTap: _handleJoinRoom,
              onShare: () {
                dismissRoomSeatActionPill();
                RoomToast.show(context, 'Share room invite opened');
              },
              onAnnouncement: () {
                dismissRoomSeatActionPill();
                _openAnnouncementSheet();
              },
              onSettings: () {
                dismissRoomSeatActionPill();
                _openSettingsSheet();
              },
              onUsersTap: () {
                dismissRoomSeatActionPill();
                _openRoomUsersSheet();
              },
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
            LiveRoomGiftOverlay(
              slides: _giftController.giftSlides,
              activeComboSlide: _giftController.activeComboSlide,
              bottomPadding: MediaQuery.paddingOf(context).bottom,
              onComboTap: _giftController.tapGiftCombo,
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
        _seatController.applyForSeat(
          index: index,
          messages: _roomMessageController.messages,
        );
      } else {
        _seatController.occupySeat(index);
      }
      return;
    }

    if (seat.user == null && _viewerCanManageRoom) {
      _seatController.toggleSelectedSeat(index);
    }
  }

  void _onUserTap(int index) {
    final user = _seatController.seats[index].user;
    if (user == null) return;
    _openMiniProfile(user, index);
  }

  void _approveSeatApplication(ChatEntry entry) {
    _seatController.approveSeatApplication(
      entry: entry,
      messages: _roomMessageController.messages,
      allRoomUsers: _allRoomUsers,
    );
  }

  void _inviteSeat(int index) {
    _seatController.clearSelectedSeat();
    _openSeatInviteSheet(index);
  }

  void _openSeatInviteSheet(int seatIndex) {
    _clearRoomFocus();

    final seatedIds = _roomUsers.map((user) => user.id).toSet();
    final inviteUsers = _allRoomUsers
        .where((user) => !seatedIds.contains(user.id))
        .toList();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => LiveRoomInviteSheet(
        seatIndex: seatIndex,
        users: inviteUsers,
        onInvite: (user) {
          Navigator.pop(context);
          RoomToast.show(
            context,
            'Invite sent to ${user.name} for seat ${seatIndex + 1}',
          );
        },
      ),
    );
  }

  void _dismissRoomOverlays() {
    dismissRoomSeatActionPill();
    _clearRoomFocus();
  }

  void _insertSystemMessage(String message) {
    _roomMessageController.insertSystemMessage(message);
  }

  void _clearRoomFocus() {
    _messageFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _toggleMic() {
    _clearRoomFocus();
    _seatController.toggleMic();
  }

  void _handleJoinRoom() {
    _clearRoomFocus();
    _roomMessageController.requestJoin();

    _openInfoSheet(
      'Join request sent',
      'Your request to become a member of $_roomName has been sent to the room owner/admins.',
    );
  }

  void _openRoomUsersSheet() {
    final users = _allRoomUsers;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RoomUserListSheet(
        users: users,
        onUserTap: (user) {
          Navigator.pop(context);
          LiveRoomProfileNavigator.openExistingPublicProfile(
            context: context,
            user: user,
            privacyMode: _privacyMode,
            roomName: _roomName,
          );
        },
      ),
    );
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _roomMessageController.sendMessage(text);
    _messageController.clear();
  }

  void _openMiniProfileFromChat(ChatEntry entry) {
    if (entry.senderId == null || entry.senderId == 'system') return;

    final user = _allRoomUsers.firstWhere(
      (item) => item.id == entry.senderId,
      orElse: () => SeatUser(
        id: entry.senderId!,
        name: entry.senderName,
        roleLabel: 'Member',
        familyName: '',
        relationshipText: '',
        vipLevel: entry.vipLevel,
        sendingLevel: entry.sendingLevel,
        receivingLevel: entry.receivingLevel,
        sentExp: 0,
        receivedExp: 0,
        medals: const [],
        avatarColors: const [RoomColors.violet, RoomColors.aqua],
      ),
    );

    final seatIndex = _seatController.seats.indexWhere(
      (seat) => seat.user?.id == user.id,
    );
    _openMiniProfile(user, seatIndex);
  }

  void _openMiniProfile(SeatUser user, int seatIndex) {
    _clearRoomFocus();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UserMiniProfileSheet(
        user: user,
        currentUser: _currentUser,
        canModerate: _viewerCanManageRoom,
        onAvatarTap: () {
          Navigator.pop(context);
          LiveRoomProfileNavigator.openExistingPublicProfile(
            context: context,
            user: user,
            privacyMode: _privacyMode,
            roomName: _roomName,
          );
        },
        onVipTap: () => LiveRoomProfileNavigator.openVipCentrePage(
          context: context,
          user: user,
        ),
        onSendingLevelTap:
            () => LiveRoomProfileNavigator.openSendingExperiencePage(
                  context: context,
                  user: user,
                ),
        onReceivingLevelTap:
            () => LiveRoomProfileNavigator.openReceivingExperiencePage(
                  context: context,
                  user: user,
                ),
        onSentRankingTap: () => LiveRoomProfileNavigator.openSentRankingsPage(
          context: context,
          users: _allRoomUsers,
        ),
        onReceivedRankingTap:
            () => LiveRoomProfileNavigator.openReceivedRankingsPage(
                  context: context,
                  users: _allRoomUsers,
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
        onMentionTap: () => _mentionUser(user),
        onSetAdminTap: () => _setUserAsAdmin(user.id),
        onLeaveAndLock: () {
          Navigator.pop(context);
          _seatController.leaveAndLockSeat(seatIndex);
        },
        onSelfMuteToggle: () {
          Navigator.pop(context);
          _seatController.toggleSelfMute(user.id);
        },
        onAdminMuteToggle: () {
          Navigator.pop(context);
          _seatController.toggleAdminMute(user.id);
        },
        onGiftTap: () {
          Navigator.pop(context);
          setState(() {
            _giftController.selectedReceiverIds
              ..clear()
              ..add(user.id);
          });
          _openGiftPanel();
        },
      ),
    );
  }

  void _mentionUser(SeatUser user) {
    Navigator.pop(context);

    final mention = '@${user.name} ';
    final current = _messageController.text;

    _messageController.text = current.endsWith(' ') || current.isEmpty
        ? '$current$mention'
        : '$current $mention';

    _messageController.selection = TextSelection.collapsed(
      offset: _messageController.text.length,
    );

    _messageFocusNode.requestFocus();
  }

  void _setUserAsAdmin(String userId) {
    Navigator.pop(context);
    _seatController.setUserAsAdmin(userId);
    _clearRoomFocus();
  }

  void _openGiftPanel() {
    _clearRoomFocus();
    _giftController.ensureDefaultReceiver(_roomUsers);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return GiftPanel(
              gifts: mockGiftItems,
              users: _roomUsers,
              selectedCategory: _giftController.selectedCategory,
              selectedGift: _giftController.selectedGift,
              selectedReceiverIds: _giftController.selectedReceiverIds,
              selectedCombo: _giftController.selectedCombo,
              coinBalance: _giftController.coinBalance,
              onCategoryChanged: (category) {
                setSheetState(() {
                  _giftController.selectCategory(category);
                });
              },
              onGiftSelected: (gift) {
                setSheetState(() => _giftController.selectGift(gift));
              },
              onReceiverToggle: (id) {
                setSheetState(() {
                  _giftController.toggleReceiver(id, _roomUsers);
                });
              },
              onComboChanged: (combo) {
                setSheetState(() => _giftController.setCombo(combo));
              },
              onSend: () {
                Navigator.pop(context);
                _giftController.sendGift(_roomUsers);
              },
              onRecharge: () {
                RoomToast.show(context, 'Wallet / coin recharge opened');
              },
            );
          },
        );
      },
    );
  }

  void _openInboxPage() {
    _clearRoomFocus();
    setState(() => _inboxUnreadCount = 0);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const InboxPage()),
    );
  }

  void _openInboxPageFromSheet(BuildContext sheetContext) {
    Navigator.pop(sheetContext);

    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!mounted) return;
      _openInboxPage();
    });
  }

  void _openEmojiTray() {
    _clearRoomFocus();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => LiveRoomEmojiSheet(
        onEmojiTap: (emoji) {
          Navigator.pop(context);
          RoomToast.show(
            context,
            '$emoji reaction will animate over avatar',
          );
        },
      ),
    );
  }

  void _openSettingsSheet() {
    _clearRoomFocus();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return RoomSettingsSheet(
            privacyMode: _privacyMode,
            roomImagesEnabled: _roomImagesEnabled,
            guestMessagesEnabled: _guestMessagesEnabled,
            applyOnlyModeEnabled: _applyOnlyModeEnabled,
            joinRequestCount: _roomMessageController.joinRequestUsers.length,
            onBackgroundTap: _openBackgroundSheet,
            onPrivacyTap: _openPrivacySheet,
            onSeatLayoutTap: _openSeatLayoutSheet,
            onAdminsTap: () => LiveRoomProfileNavigator.openModulePage(
              context: context,
              title: 'Admins',
              subtitle: 'Room administrator management will connect here.',
              icon: Icons.shield_rounded,
            ),
            onAnnouncementTap: _openAnnouncementSheet,
            onInboxTap: () => _openInboxPageFromSheet(sheetContext),
            onJoinRequestsTap: _openJoinRequestsSheet,
            onReportsTap: () => LiveRoomProfileNavigator.openModulePage(
              context: context,
              title: 'Reports',
              subtitle:
                  'Room safety, reports, and moderation queue will connect here.',
              icon: Icons.report_gmailerrorred_rounded,
            ),
            onBlockedTap: () => LiveRoomProfileNavigator.openModulePage(
              context: context,
              title: 'Blocked users',
              subtitle: 'Blocked and restricted room users will connect here.',
              icon: Icons.block_rounded,
            ),
            onEffectsTap: () => LiveRoomProfileNavigator.openModulePage(
              context: context,
              title: 'Room effects',
              subtitle:
                  'Room entrance effects, seat effects, and background effects will connect here.',
              icon: Icons.auto_awesome_rounded,
            ),
            onMusicTap: () => LiveRoomProfileNavigator.openModulePage(
              context: context,
              title: 'Music',
              subtitle: 'Room music controls and playlist will connect here.',
              icon: Icons.music_note_rounded,
            ),
            onToggleRoomImages: (value) {
              setState(() => _roomImagesEnabled = value);
              setSheetState(() {});
              _insertSystemMessage(
                value ? 'Images enabled' : 'Images disabled',
              );
            },
            onToggleGuestMessages: (value) {
              setState(() => _guestMessagesEnabled = value);
              setSheetState(() {});
              _insertSystemMessage(
                value ? 'Guest messages enabled' : 'Guest messages disabled',
              );
            },
            onToggleApplyOnlyMode: (value) {
              setState(() => _applyOnlyModeEnabled = value);
              setSheetState(() {});
              _insertSystemMessage(
                value ? 'Apply mode enabled' : 'Free mode enabled',
              );
            },
            onCloseRoom: () => _leaveRoomFromSheet(context),
          );
        },
      ),
    );
  }

  void _openJoinRequestsSheet() {
    _clearRoomFocus();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          return LiveRoomJoinRequestsSheet(
            users: _roomMessageController.joinRequestUsers,
            onApprove: (user) {
              _resolveJoinRequest(user, approved: true);
              setSheetState(() {});
            },
            onReject: (user) {
              _resolveJoinRequest(user, approved: false);
              setSheetState(() {});
            },
          );
        },
      ),
    );
  }

  void _resolveJoinRequest(SeatUser user, {required bool approved}) {
    _roomMessageController.resolveJoinRequest(
      user: user,
      approved: approved,
      roomName: _roomName,
    );

    RoomToast.show(
      context,
      approved ? '${user.name} approved' : '${user.name} rejected',
    );
  }

  void _openPrivacySheet() {
    _clearRoomFocus();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PrivacySettingsSheet(
        currentMode: _privacyMode,
        onModeChanged: (mode) {
          setState(() => _privacyMode = mode);
          _insertSystemMessage('Room mode changed to ${mode.label}');
        },
      ),
    );
  }

  void _openGamesSheet() {
    _clearRoomFocus();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => LiveRoomGamesSheet(
        onCrystalHuntTap: () {
          Navigator.pop(context);
          RoomToast.show(context, 'Crystal Hunt opens here');
        },
        onLudoTap: () {
          Navigator.pop(context);
          RoomToast.show(context, 'Ludo opens here');
        },
        onCarromTap: () {
          Navigator.pop(context);
          RoomToast.show(context, 'Carrom opens here');
        },
        onPkTap: () {
          Navigator.pop(context);
          RoomToast.show(context, 'PK game opens here');
        },
      ),
    );
  }

  void _openSeatLayoutSheet() {
    _clearRoomFocus();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SeatLayoutSheet(
        selectedLayout: _seatController.layoutId,
        onSelected: (layout) {
          _seatController.changeLayout(layout);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _openBackgroundSheet() {
    _clearRoomFocus();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RoomBackgroundPickerSheet(
        currentTheme: _selectedBackgroundTheme,
        onThemeSelected: (theme) {
          setState(() => _selectedBackgroundTheme = theme);
          RoomToast.show(context, '${theme.name} applied');
        },
        onStoreTap: () => RoomToast.show(context, 'Theme store opened'),
      ),
    );
  }

  void _openAnnouncementSheet() {
    _clearRoomFocus();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LiveRoomAnnouncementSheet(
        controller: _announcementController,
        onSubmit: (message) {
          Navigator.pop(context);

          if (message.isNotEmpty) {
            _insertSystemMessage(message);
            _announcementController.clear();
          }

          RoomToast.show(context, 'Announcement saved');
        },
      ),
    );
  }

  void _openLeaveSheet() {
    dismissRoomSeatActionPill();

    if (_leaveSheetOpen || _exitingRoom) return;

    _leaveSheetOpen = true;
    _clearRoomFocus();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => LiveRoomLeaveSheet(
        onStay: () {
          dismissRoomSeatActionPill();
          _stayAndMinimize(sheetContext);
        },
        onLeave: () {
          dismissRoomSeatActionPill();
          _leaveRoomFromSheet(sheetContext);
        },
      ),
    ).whenComplete(() => _leaveSheetOpen = false);
  }

  void _stayAndMinimize(BuildContext sheetContext) {
    Navigator.pop(sheetContext);
    setState(() => _minimized = true);
  }

  void _leaveRoomFromSheet(BuildContext sheetContext) {
    if (_exitingRoom) return;

    _exitingRoom = true;
    Navigator.pop(sheetContext);

    if (!mounted) return;

    setState(() => _allowRoomPop = true);

    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (mounted) Navigator.maybePop(context);
    });
  }

  void _openInfoSheet(String title, String body) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => LiveRoomInfoSheet(
        title: title,
        body: body,
      ),
    );
  }
}