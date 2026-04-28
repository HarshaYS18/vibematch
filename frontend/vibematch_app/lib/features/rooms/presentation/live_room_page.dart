import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/models/current_user.dart';
import '../../inbox/presentation/inbox_page.dart';
import '../../profile/presentation/public_profile_view_page.dart';
import 'live_room_models.dart';
import 'widgets/live_room_games_sheet.dart';
import 'widgets/live_room_invite_sheet.dart';
import 'widgets/live_room_join_requests_sheet.dart';
import 'widgets/live_room_minimized_bubble.dart';
import 'widgets/room_action_pages.dart';
import 'widgets/room_chat.dart';
import 'widgets/room_gifts.dart';
import 'widgets/room_profile_sheet.dart';
import 'widgets/room_seats.dart';
import 'widgets/room_settings_sheet.dart';
import 'widgets/room_theme.dart';
import 'widgets/room_top_bar.dart';
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

  late String _roomName;
  late String _roomId;
  late RoomPrivacyMode _privacyMode;
  late List<RoomSeat> _seats;
  late List<ChatEntry> _messages;

  String _layoutId = '5x2';
  int? _selectedSeatIndex;
  bool _roomImagesEnabled = true;
  bool _guestMessagesEnabled = true;
  bool _micMuted = false;
  bool _minimized = false;
  bool _allowRoomPop = false;
  bool _leaveSheetOpen = false;
  bool _exitingRoom = false;
  bool _applyOnlyModeEnabled = false;
  int _coinBalance = 35494;
  int _inboxUnreadCount = 4;

  Offset _bubbleOffset = const Offset(24, 120);
  RoomBackgroundTheme _selectedBackgroundTheme = defaultRoomBackgroundTheme;

  final List<SeatUser> _joinRequestUsers = <SeatUser>[
    mockInviteUsers[0],
    mockInviteUsers[1],
  ];

  GiftCategory _selectedGiftCategory = GiftCategory.classic;
  GiftItem? _selectedGift = mockGiftItems.first;
  final Set<String> _selectedReceiverIds = <String>{};
  int _selectedCombo = 1;
  final List<GiftSlide> _giftSlides = <GiftSlide>[];
  final Map<String, Timer> _giftTimers = <String, Timer>{};
  final Set<String> _finishedGiftMessageIds = <String>{};

  final SeatUser _currentUser = mockRoomUsers.first;

  List<SeatUser> get _roomUsers {
    return _seats
        .where((seat) => seat.user != null)
        .map((seat) => seat.user!)
        .toList();
  }

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

  GiftSlide? get _activeComboSlide =>
      _giftSlides.isEmpty ? null : _giftSlides.first;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _announcementController = TextEditingController();
    _messageFocusNode = FocusNode();
    _roomName = widget.roomName;
    _roomId = widget.roomId;
    _privacyMode = privacyModeFromTitle(widget.modeTitle);
    _messages = List<ChatEntry>.from(mockChatEntries);
    _seats = _buildSeatsForLayout(_layoutId);

    if (_roomUsers.isNotEmpty) {
      _selectedReceiverIds.add(_roomUsers.first.id);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _announcementController.dispose();
    _messageFocusNode.dispose();

    for (final timer in _giftTimers.values) {
      timer.cancel();
    }

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
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: RoomTopBar(
                      roomName: _roomName,
                      roomId: _roomId,
                      privacyMode: _privacyMode,
                      onlineCount: _safeOnlineCount,
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
                    ),
                  ),
                  const SizedBox(height: 22),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: RoomSeatLayout(
                      seats: _seats,
                      layoutId: _layoutId,
                      selectedSeatIndex: _selectedSeatIndex,
                      canManageSeats: _viewerCanManageRoom,
                      onSeatTap: _onSeatTap,
                      onUserTap: _onUserTap,
                      onInvite: _inviteSeat,
                      onSwitch: _switchSeat,
                      onLock: _lockSeat,
                      onUnlock: _unlockSeat,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _dismissRoomOverlays,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: RoomChatFeed(
                          messages: _messages,
                          canManageSeatApplications: _viewerCanManageRoom,
                          onApproveSeatApplication: _approveSeatApplication,
                          onSenderTap: _openMiniProfileFromChat,
                        ),
                      ),
                    ),
                  ),
                  RoomInputDock(
                    controller: _messageController,
                    focusNode: _messageFocusNode,
                    micMuted: _micMuted,
                    inboxUnreadCount: _inboxUnreadCount,
                    imagesEnabled: _roomImagesEnabled,
                    onInboxTap: _openInboxPage,
                    onEmojiTap: _openEmojiTray,
                    onSendTap: _sendMessage,
                    onMicTap: _toggleMic,
                    onGamesTap: _openGamesSheet,
                    onGiftTap: _openGiftPanel,
                  ),
                ],
              ),
            ),
            Positioned(
              left: 12,
              top: 218,
              child: GiftSlideStack(
                slides: _giftSlides,
                onComboTap: _tapGiftCombo,
              ),
            ),
            Positioned(
              right: 18,
              bottom: 52 + MediaQuery.paddingOf(context).bottom,
              child: ComboBuzzer(
                slide: _activeComboSlide,
                onTap: () {
                  dismissRoomSeatActionPill();
                  final slide = _activeComboSlide;
                  if (slide != null) _tapGiftCombo(slide);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<RoomSeat> _buildSeatsForLayout(String layoutId) {
    final spec = SeatLayoutSpec.parse(layoutId);
    final seats = List<RoomSeat>.generate(
      spec.totalSeats,
      (index) => RoomSeat(index: index),
    );

    for (var i = 0; i < mockRoomUsers.length && i < seats.length; i++) {
      seats[i] = RoomSeat(index: i, user: mockRoomUsers[i]);
    }

    return seats;
  }

  void _onSeatTap(int index) {
    final seat = _seats[index];

    if (seat.locked) {
      if (_viewerCanManageRoom) {
        setState(
          () => _selectedSeatIndex = _selectedSeatIndex == index ? null : index,
        );
      } else {
        RoomToast.show(context, 'This seat is locked');
      }
      return;
    }

    if (seat.user == null && !_viewerCanManageRoom) {
      if (_applyOnlyModeEnabled) {
        _applyForSeat(index);
      } else {
        _occupySeat(index);
      }
      return;
    }

    if (seat.user == null && _viewerCanManageRoom) {
      setState(
        () => _selectedSeatIndex = _selectedSeatIndex == index ? null : index,
      );
    }
  }

  void _onUserTap(int index) {
    final user = _seats[index].user;
    if (user == null) return;
    _openMiniProfile(user, index);
  }

  void _occupySeat(int index) {
    setState(() {
      final oldIndex = _seats.indexWhere(
        (seat) => seat.user?.id == _currentUser.id,
      );
      if (oldIndex >= 0) {
        _seats[oldIndex] = _seats[oldIndex].copyWith(clearUser: true);
      }
      _seats[index] = _seats[index].copyWith(
        user: _currentUser,
        locked: false,
      );
      _selectedSeatIndex = null;
    });
  }

  void _applyForSeat(int index) {
    final alreadyApplied = _messages.any(
      (message) =>
          message.isSeatApplication &&
          !message.applicationApproved &&
          message.senderId == _currentUser.id &&
          message.seatIndex == index,
    );

    if (alreadyApplied) {
      RoomToast.show(context, 'Seat application already sent');
      return;
    }

    setState(() {
      _selectedSeatIndex = null;
      _messages.insert(
        0,
        ChatEntry(
          senderName: _currentUser.name,
          senderId: _currentUser.id,
          message: 'applied for seat ${index + 1}',
          vipLevel: _currentUser.vipLevel,
          sendingLevel: _currentUser.sendingLevel,
          receivingLevel: _currentUser.receivingLevel,
          isSeatApplication: true,
          seatIndex: index,
        ),
      );
    });

    RoomToast.show(context, 'Seat application sent');
  }

  void _approveSeatApplication(ChatEntry entry) {
    final seatIndex = entry.seatIndex;
    if (seatIndex == null || seatIndex < 0 || seatIndex >= _seats.length) {
      return;
    }

    if (_seats[seatIndex].user != null || _seats[seatIndex].locked) {
      setState(() {
        final index = _messages.indexOf(entry);
        if (index >= 0) {
          _messages[index] = entry.copyWith(
            message: '${entry.message} • seat unavailable',
            applicationApproved: true,
          );
        }
      });
      return;
    }

    final applicant = _allRoomUsers.firstWhere(
      (user) => user.id == entry.senderId,
      orElse: () => _currentUser,
    );

    setState(() {
      _seats[seatIndex] = _seats[seatIndex].copyWith(
        user: applicant,
        locked: false,
      );

      final index = _messages.indexOf(entry);
      if (index >= 0) {
        _messages[index] = entry.copyWith(
          message: '${entry.senderName} approved for seat ${seatIndex + 1}',
          applicationApproved: true,
        );
      }
    });
  }

  void _inviteSeat(int index) {
    setState(() => _selectedSeatIndex = null);
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

  void _switchSeat(int index) {
    _occupySeat(index);
    RoomToast.show(context, 'Switched to seat ${index + 1}');
  }

  void _lockSeat(int index) {
    setState(() {
      _seats[index] = _seats[index].copyWith(locked: true, clearUser: true);
      _selectedSeatIndex = null;
    });
    RoomToast.show(context, 'Seat ${index + 1} locked');
  }

  void _unlockSeat(int index) {
    setState(() {
      _seats[index] = _seats[index].copyWith(locked: false);
      _selectedSeatIndex = null;
    });
    RoomToast.show(context, 'Seat ${index + 1} unlocked');
  }

  void _dismissRoomOverlays() {
    dismissRoomSeatActionPill();
    _clearRoomFocus();
  }

  void _insertSystemMessage(String message) {
    setState(() {
      _messages.insert(
        0,
        ChatEntry(
          senderName: 'System',
          senderId: 'system',
          message: message,
        ),
      );
    });
  }

  void _clearRoomFocus() {
    _messageFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _toggleMic() {
    _clearRoomFocus();

    setState(() {
      _micMuted = !_micMuted;

      final index = _seats.indexWhere(
        (seat) => seat.user?.id == _currentUser.id,
      );

      if (index >= 0) {
        final user = _seats[index].user!;
        _seats[index] = _seats[index].copyWith(
          user: user.copyWith(selfMuted: _micMuted),
        );
      }
    });
  }

  void _handleJoinRoom() {
    _clearRoomFocus();

    final alreadyRequested = _joinRequestUsers.any(
      (user) => user.id == _currentUser.id,
    );

    if (!alreadyRequested) {
      setState(() => _joinRequestUsers.add(_currentUser));
    }

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
          _openExistingPublicProfile(user);
        },
      ),
    );
  }

  void _openExistingPublicProfile(SeatUser user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicProfileViewPage(
          user: _seatUserToCurrentUser(user),
          vipLevel: user.vipLevel,
          svipLevel: user.vipLevel >= 25 ? 3 : 0,
          presenceLabel: 'online',
          currentRoomName: _privacyMode == RoomPrivacyMode.privateVibe
              ? null
              : _roomName,
          relationshipLabel: user.relationshipText,
          familyName: user.familyName,
          familyLevel: 12,
        ),
      ),
    );
  }

  CurrentUser _seatUserToCurrentUser(SeatUser user) {
    final isFounder = user.id == 'founder_owner';
    final isAdmin = user.isRoomAdmin || user.isHost;

    final role = isFounder
        ? 'founder_owner'
        : user.isHost
            ? 'owner'
            : isAdmin
                ? 'admin'
                : 'user';

    return CurrentUser(
      id: _mockInternalUserId(user),
      publicUserId: _mockPublicUserId(user),
      displayCustomId: isFounder ? 6922022 : null,
      username: user.name.toLowerCase().replaceAll(' ', '_'),
      displayName: user.name,
      avatarUrl: null,
      roles: [role],
      primaryRole: role,
      isActive: true,
      isBanned: false,
      lastDeviceId: null,
      lastLoginAt: DateTime.now(),
      lastSeenAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  int _mockInternalUserId(SeatUser user) {
    switch (user.id) {
      case 'founder_owner':
        return 1;
      case 'riya':
        return 2;
      case 'arjun':
        return 3;
      default:
        return user.id.hashCode.abs() % 900000 + 100000;
    }
  }

  int _mockPublicUserId(SeatUser user) {
    switch (user.id) {
      case 'founder_owner':
        return 6922022;
      case 'riya':
        return 6418001245;
      case 'arjun':
        return 6418002480;
      default:
        return 6418000000 + (user.id.hashCode.abs() % 999999);
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.insert(
        0,
        ChatEntry(
          senderName: _currentUser.name,
          senderId: _currentUser.id,
          message: text,
          vipLevel: _currentUser.vipLevel,
          sendingLevel: _currentUser.sendingLevel,
          receivingLevel: _currentUser.receivingLevel,
        ),
      );
      _messageController.clear();
    });
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

    final seatIndex = _seats.indexWhere((seat) => seat.user?.id == user.id);
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
          _openExistingPublicProfile(user);
        },
        onVipTap: () => _openVipCentrePage(user),
        onSendingLevelTap: () => _openSendingExperiencePage(user),
        onReceivingLevelTap: () => _openReceivingExperiencePage(user),
        onSentRankingTap: _openSentRankingsPage,
        onReceivedRankingTap: _openReceivedRankingsPage,
        onFamilyTap: () => _openFamilyPage(user),
        onRelationshipTap: () => _openLoveAndBondCentre(user),
        onMedalsTap: () => _openMedalsPage(user),
        onMentionTap: () => _mentionUser(user),
        onSetAdminTap: () => _setUserAsAdmin(user.id),
        onLeaveAndLock: () {
          Navigator.pop(context);
          if (seatIndex >= 0 && seatIndex < _seats.length) {
            setState(
              () => _seats[seatIndex] = RoomSeat(
                index: seatIndex,
                locked: true,
              ),
            );
          }
        },
        onSelfMuteToggle: () {
          Navigator.pop(context);
          _toggleSelfMute(user.id);
        },
        onAdminMuteToggle: () {
          Navigator.pop(context);
          _toggleAdminMute(user.id);
        },
        onGiftTap: () {
          Navigator.pop(context);
          setState(() {
            _selectedReceiverIds
              ..clear()
              ..add(user.id);
          });
          _openGiftPanel();
        },
      ),
    );
  }

  void _toggleSelfMute(String userId) {
    final index = _seats.indexWhere((seat) => seat.user?.id == userId);
    if (index < 0) return;

    final user = _seats[index].user!;
    setState(
      () => _seats[index] = _seats[index].copyWith(
        user: user.copyWith(selfMuted: !user.selfMuted),
      ),
    );
  }

  void _toggleAdminMute(String userId) {
    final index = _seats.indexWhere((seat) => seat.user?.id == userId);
    if (index < 0) return;

    final user = _seats[index].user!;

    if (user.selfMuted) {
      RoomToast.show(
        context,
        'User muted themselves. Admin cannot unmute self mute.',
      );
      return;
    }

    setState(
      () => _seats[index] = _seats[index].copyWith(
        user: user.copyWith(adminMuted: !user.adminMuted),
      ),
    );
  }

  void _pushRoomActionPageFromSheet(Widget page) {
    _clearRoomFocus();
    Navigator.pop(context);

    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    });
  }

  void _openVipCentrePage(SeatUser user) {
    _pushRoomActionPageFromSheet(
      RoomActionPage(
        title: 'VIP Centre',
        subtitle:
            '${user.name} is VIP ${user.vipLevel}. VIP benefits, SVIP rules, badges, and recharge progress will connect here.',
        icon: Icons.workspace_premium_rounded,
        cards: [
          RoomActionCard(
            title: 'Current VIP',
            value: 'VIP ${user.vipLevel}',
            icon: Icons.workspace_premium_rounded,
            color: RoomColors.gold,
          ),
          RoomActionCard(
            title: 'Monthly status',
            value: user.vipLevel >= 25
                ? 'Dynamic avatar unlocked'
                : 'Recharge to unlock more perks',
            icon: Icons.auto_awesome_rounded,
            color: RoomColors.violet,
          ),
        ],
      ),
    );
  }

  void _openSendingExperiencePage(SeatUser user) {
    _pushRoomActionPageFromSheet(
      RoomActionPage(
        title: 'Sending Experience',
        subtitle:
            '${user.name}\'s total sending level progress and monthly coin-send history.',
        icon: Icons.north_east_rounded,
        cards: [
          RoomActionCard(
            title: 'Send level',
            value: 'Lv ${user.sendingLevel}',
            icon: Icons.north_east_rounded,
            color: RoomColors.violet,
          ),
          RoomActionCard(
            title: 'This month sent',
            value: compactNumber(user.sentExp),
            icon: Icons.toll_rounded,
            color: RoomColors.gold,
          ),
        ],
      ),
    );
  }

  void _openReceivingExperiencePage(SeatUser user) {
    _pushRoomActionPageFromSheet(
      RoomActionPage(
        title: 'Receiving Experience',
        subtitle:
            '${user.name}\'s receiving level progress and monthly received coin history.',
        icon: Icons.favorite_rounded,
        cards: [
          RoomActionCard(
            title: 'Receive level',
            value: 'Lv ${user.receivingLevel}',
            icon: Icons.favorite_rounded,
            color: RoomColors.coral,
          ),
          RoomActionCard(
            title: 'This month received',
            value: compactNumber(user.receivedExp),
            icon: Icons.toll_rounded,
            color: RoomColors.gold,
          ),
        ],
      ),
    );
  }

  void _openSentRankingsPage() {
    _pushRoomActionPageFromSheet(
      RoomRankingsPage(
        title: 'Sent Rankings',
        users: _allRoomUsers,
        sentRanking: true,
      ),
    );
  }

  void _openReceivedRankingsPage() {
    _pushRoomActionPageFromSheet(
      RoomRankingsPage(
        title: 'Received Rankings',
        users: _allRoomUsers,
        sentRanking: false,
      ),
    );
  }

  void _openFamilyPage(SeatUser user) {
    final hasFamily = user.familyName.trim().isNotEmpty;

    _pushRoomActionPageFromSheet(
      RoomActionPage(
        title: hasFamily ? user.familyName : 'Join Family',
        subtitle: hasFamily
            ? '${user.name}\'s family profile, contribution, family rooms, events, and rankings.'
            : '${user.name} is not in a family yet. Family discovery and create/join flow will connect here.',
        icon: Icons.groups_rounded,
        cards: [
          RoomActionCard(
            title: hasFamily ? 'Family name' : 'Status',
            value: hasFamily ? user.familyName : 'No family joined',
            icon: Icons.groups_rounded,
            color: RoomColors.aqua,
          ),
          RoomActionCard(
            title: 'Family events',
            value: 'Family-vs-family activities and rewards connect here',
            icon: Icons.emoji_events_rounded,
            color: RoomColors.gold,
          ),
        ],
      ),
    );
  }

  void _openLoveAndBondCentre(SeatUser user) {
    _pushRoomActionPageFromSheet(
      RoomActionPage(
        title: 'Love & Bond Centre',
        subtitle: user.relationshipText.trim().isEmpty
            ? '${user.name} has no active love or bond relationship yet.'
            : user.relationshipText,
        icon: Icons.favorite_rounded,
        cards: [
          RoomActionCard(
            title: 'Relationship',
            value: user.relationshipText.trim().isEmpty
                ? 'No love or bonds yet'
                : user.relationshipText,
            icon: Icons.favorite_rounded,
            color: RoomColors.coral,
          ),
          RoomActionCard(
            title: 'Cards',
            value: 'Relationship cards and bond actions connect here',
            icon: Icons.style_rounded,
            color: RoomColors.violet,
          ),
        ],
      ),
    );
  }

  void _openMedalsPage(SeatUser user) {
    _pushRoomActionPageFromSheet(
      RoomActionPage(
        title: 'Medals',
        subtitle:
            '${user.name}\'s earned medals and upcoming achievement badges.',
        icon: Icons.military_tech_rounded,
        cards: [
          RoomActionCard(
            title: 'Current medals',
            value: user.medals.isEmpty ? 'No medals yet' : user.medals.join('  '),
            icon: Icons.military_tech_rounded,
            color: RoomColors.gold,
          ),
          RoomActionCard(
            title: 'Achievement centre',
            value: 'Medal progress and rules connect here',
            icon: Icons.auto_graph_rounded,
            color: RoomColors.aqua,
          ),
        ],
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

    setState(() {
      for (var i = 0; i < _seats.length; i++) {
        final user = _seats[i].user;
        if (user?.id == userId) {
          _seats[i] = _seats[i].copyWith(
            user: user!.copyWith(
              isRoomAdmin: true,
              roleLabel: 'Administrator',
            ),
          );
        }
      }
    });

    _clearRoomFocus();
  }

  void _openModulePage(String title, String subtitle, IconData icon) {
    _clearRoomFocus();
    Navigator.pop(context);

    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RoomActionPage(
            title: title,
            subtitle: subtitle,
            icon: icon,
          ),
        ),
      );
    });
  }

  void _openGiftPanel() {
    _clearRoomFocus();

    if (_selectedReceiverIds.isEmpty && _roomUsers.isNotEmpty) {
      _selectedReceiverIds.add(_roomUsers.first.id);
    }

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
              selectedCategory: _selectedGiftCategory,
              selectedGift: _selectedGift,
              selectedReceiverIds: _selectedReceiverIds,
              selectedCombo: _selectedCombo,
              coinBalance: _coinBalance,
              onCategoryChanged: (category) {
                setSheetState(() {
                  _selectedGiftCategory = category;

                  final categoryGifts = mockGiftItems
                      .where((gift) => gift.category == category)
                      .toList();

                  if (categoryGifts.isNotEmpty) {
                    _selectedGift = categoryGifts.first;
                  }

                  if (category == GiftCategory.lucky && _selectedCombo < 9) {
                    _selectedCombo = 9;
                  }
                });
              },
              onGiftSelected: (gift) {
                setSheetState(() => _selectedGift = gift);
              },
              onReceiverToggle: (id) {
                setSheetState(() {
                  if (id == '__all__') {
                    if (_selectedReceiverIds.length == _roomUsers.length) {
                      _selectedReceiverIds.clear();
                    } else {
                      _selectedReceiverIds
                        ..clear()
                        ..addAll(_roomUsers.map((user) => user.id));
                    }
                    return;
                  }

                  if (_selectedReceiverIds.contains(id)) {
                    _selectedReceiverIds.remove(id);
                  } else {
                    _selectedReceiverIds.add(id);
                  }
                });
              },
              onComboChanged: (combo) {
                setSheetState(() => _selectedCombo = combo);
              },
              onSend: () {
                Navigator.pop(context);
                _sendGift();
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

  void _sendGift() {
    final gift = _selectedGift;
    if (gift == null) return;

    final receivers = _roomUsers
        .where((user) => _selectedReceiverIds.contains(user.id))
        .toList();

    if (receivers.isEmpty) {
      RoomToast.show(context, 'Select a receiver');
      return;
    }

    final totalCost = gift.coins * _selectedCombo * receivers.length;

    if (_coinBalance < totalCost) {
      RoomToast.show(context, 'Not enough coins');
      return;
    }

    setState(() => _coinBalance -= totalCost);

    final sentToAll =
        receivers.length == _roomUsers.length && _roomUsers.isNotEmpty;
    final targets = sentToAll ? <SeatUser?>[null] : receivers.cast<SeatUser?>();

    for (final receiver in targets) {
      final slide = GiftSlide(
        id: '${receiver?.id ?? 'all'}-${DateTime.now().microsecondsSinceEpoch}',
        senderName: _currentUser.name,
        receiverName: receiver?.name ?? 'all',
        giftName: gift.name,
        giftIcon: gift.icon,
        colors: gift.colors,
        combo: _selectedCombo,
        remainingSeconds: 15,
      );
      _startGiftSlide(slide);
    }
  }

  void _startGiftSlide(GiftSlide slide) {
    setState(() => _giftSlides.insert(0, slide));

    _giftTimers[slide.id]?.cancel();
    _giftTimers[slide.id] = Timer.periodic(const Duration(seconds: 1), (timer) {
      final index = _giftSlides.indexWhere((item) => item.id == slide.id);

      if (index < 0) {
        timer.cancel();
        return;
      }

      final active = _giftSlides[index];

      if (active.remainingSeconds <= 1) {
        timer.cancel();
        setState(() => _giftSlides.removeAt(index));
        _giftTimers.remove(slide.id);
        _insertFinalGiftMessage(active);
        return;
      }

      setState(
        () => _giftSlides[index] = active.copyWith(
          remainingSeconds: active.remainingSeconds - 1,
        ),
      );
    });
  }

  void _tapGiftCombo(GiftSlide slide) {
    final index = _giftSlides.indexWhere((item) => item.id == slide.id);
    if (index < 0) return;

    final active = _giftSlides[index];

    setState(() {
      _giftSlides[index] = active.copyWith(
        combo: active.combo + 1,
        remainingSeconds: 15,
      );
    });
  }

  void _insertFinalGiftMessage(GiftSlide slide) {
    if (!_finishedGiftMessageIds.add(slide.id)) return;

    setState(() {
      _messages.insert(
        0,
        ChatEntry(
          senderName: slide.senderName,
          senderId: _currentUser.id,
          message: 'sent to ${slide.receiverName} 🎁 x${slide.combo}',
          vipLevel: _currentUser.vipLevel,
          sendingLevel: _currentUser.sendingLevel,
          receivingLevel: _currentUser.receivingLevel,
          isGift: true,
        ),
      );
    });
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
      builder: (_) => Container(
        padding: EdgeInsets.fromLTRB(
          18,
          12,
          18,
          MediaQuery.paddingOf(context).bottom + 16,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: ['😍', '😂', '🔥', '👏', '💖', '😎', '🎉', '💎'].map(
            (emoji) {
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  RoomToast.show(
                    context,
                    '$emoji reaction will animate over avatar',
                  );
                },
                child: Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: RoomColors.pearl,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: RoomColors.softLine),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 28)),
                ),
              );
            },
          ).toList(),
        ),
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
            joinRequestCount: _joinRequestUsers.length,
            onBackgroundTap: _openBackgroundSheet,
            onPrivacyTap: _openPrivacySheet,
            onSeatLayoutTap: _openSeatLayoutSheet,
            onAdminsTap: () => _openModulePage(
              'Admins',
              'Room administrator management will connect here.',
              Icons.shield_rounded,
            ),
            onAnnouncementTap: _openAnnouncementSheet,
            onInboxTap: () => _openInboxPageFromSheet(sheetContext),
            onJoinRequestsTap: _openJoinRequestsSheet,
            onReportsTap: () => _openModulePage(
              'Reports',
              'Room safety, reports, and moderation queue will connect here.',
              Icons.report_gmailerrorred_rounded,
            ),
            onBlockedTap: () => _openModulePage(
              'Blocked users',
              'Blocked and restricted room users will connect here.',
              Icons.block_rounded,
            ),
            onEffectsTap: () => _openModulePage(
              'Room effects',
              'Room entrance effects, seat effects, and background effects will connect here.',
              Icons.auto_awesome_rounded,
            ),
            onMusicTap: () => _openModulePage(
              'Music',
              'Room music controls and playlist will connect here.',
              Icons.music_note_rounded,
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
            users: _joinRequestUsers,
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
    setState(() {
      _joinRequestUsers.removeWhere((item) => item.id == user.id);
      _messages.insert(
        0,
        ChatEntry(
          senderName: _currentUser.name,
          senderId: _currentUser.id,
          message: approved
              ? 'approved ${user.name} to join $_roomName'
              : 'rejected ${user.name}\'s join request',
          vipLevel: _currentUser.vipLevel,
          sendingLevel: _currentUser.sendingLevel,
          receivingLevel: _currentUser.receivingLevel,
        ),
      );
    });

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
        selectedLayout: _layoutId,
        onSelected: (layout) {
          setState(() {
            _layoutId = layout;
            _seats = _buildSeatsForLayout(layout);
            _selectedSeatIndex = null;
          });
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
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            18,
            12,
            18,
            MediaQuery.paddingOf(context).bottom + 16,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              const SizedBox(height: 16),
              const Text(
                'Broad Announcement',
                style: TextStyle(
                  color: RoomColors.plum,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _announcementController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Type announcement...',
                  filled: true,
                  fillColor: RoomColors.pearl,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final message = _announcementController.text.trim();
                    Navigator.pop(context);

                    if (message.isNotEmpty) {
                      _insertSystemMessage(message);
                      _announcementController.clear();
                    }

                    RoomToast.show(context, 'Announcement saved');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RoomColors.plum,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text('Submit'),
                ),
              ),
            ],
          ),
        ),
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
      builder: (sheetContext) => Container(
        padding: EdgeInsets.fromLTRB(
          18,
          12,
          18,
          MediaQuery.paddingOf(context).bottom + 16,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            const SizedBox(height: 16),
            const Text(
              'Leave room?',
              style: TextStyle(
                color: RoomColors.plum,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Stay will minimize this chatroom into a floating bubble.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF7B6A86),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      dismissRoomSeatActionPill();
                      _stayAndMinimize(sheetContext);
                    },
                    child: const Text('Stay'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      dismissRoomSeatActionPill();
                      _leaveRoomFromSheet(sheetContext);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: RoomColors.plum,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Leave'),
                  ),
                ),
              ],
            ),
          ],
        ),
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
      builder: (_) => Container(
        padding: EdgeInsets.fromLTRB(
          18,
          12,
          18,
          MediaQuery.paddingOf(context).bottom + 16,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: RoomColors.plum,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: const TextStyle(
                color: Color(0xFF7B6A86),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}