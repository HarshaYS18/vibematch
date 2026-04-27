import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/models/current_user.dart';
import '../../profile/presentation/public_profile_view_page.dart';
import '../../inbox/presentation/inbox_page.dart';
import 'live_room_models.dart';
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
  bool _applyOnlyModeEnabled = false;
  int _coinBalance = 35494;
  int _inboxUnreadCount = 4;
  Offset _bubbleOffset = const Offset(24, 120);
  RoomBackgroundTheme _selectedBackgroundTheme = defaultRoomBackgroundTheme;
  final List<SeatUser> _joinRequestUsers = <SeatUser>[mockInviteUsers[0], mockInviteUsers[1]];

  GiftCategory _selectedGiftCategory = GiftCategory.classic;
  GiftItem? _selectedGift = mockGiftItems.first;
  final Set<String> _selectedReceiverIds = <String>{};
  int _selectedCombo = 1;
  final List<GiftSlide> _giftSlides = <GiftSlide>[];
  final Map<String, Timer> _giftTimers = <String, Timer>{};

  final SeatUser _currentUser = mockRoomUsers.first;

  List<SeatUser> get _roomUsers {
    return _seats.where((seat) => seat.user != null).map((seat) => seat.user!).toList();
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

  bool get _viewerCanManageRoom => _currentUser.isHost || _currentUser.isRoomAdmin;

  int get _safeOnlineCount {
    return _allRoomUsers.length;
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
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(child: RoomBackground(theme: _selectedBackgroundTheme)),
            Positioned(
              left: _bubbleOffset.dx,
              top: _bubbleOffset.dy,
              child: GestureDetector(
                onTap: () => setState(() => _minimized = false),
                onPanUpdate: (details) {
                  final size = MediaQuery.sizeOf(context);
                  setState(() {
                    _bubbleOffset = Offset(
                      (_bubbleOffset.dx + details.delta.dx).clamp(8.0, size.width - 86),
                      (_bubbleOffset.dy + details.delta.dy).clamp(40.0, size.height - 120),
                    );
                  });
                },
                child: Container(
                  width: 78,
                  height: 54,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(colors: [RoomColors.aqua, RoomColors.violet]),
                    boxShadow: [BoxShadow(color: RoomColors.aqua.withValues(alpha: 0.3), blurRadius: 22, offset: const Offset(0, 10))],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 24),
                      SizedBox(width: 5),
                      Text('Live', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        _openLeaveSheet();
        return false;
      },
      child: Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: RoomColors.deep,
      body: Stack(
        children: [
          Positioned.fill(child: RoomBackground(theme: _selectedBackgroundTheme)),
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
                    onShare: () => RoomToast.show(context, 'Share room invite opened'),
                    onAnnouncement: _openAnnouncementSheet,
                    onSettings: _openSettingsSheet,
                    onUsersTap: _openRoomUsersSheet,
                  ),
                ),
                const SizedBox(height: 8),
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: RoomChatFeed(
                      messages: _messages,
                      canManageSeatApplications: _viewerCanManageRoom,
                      onApproveSeatApplication: _approveSeatApplication,
                    ),
                  ),
                ),
                RoomInputDock(
                  controller: _messageController,
                  focusNode: _messageFocusNode,
                  micMuted: _micMuted,
                  inboxUnreadCount: _inboxUnreadCount,
                  showImageButton: _roomImagesEnabled,
                  onInboxTap: _openInboxSheet,
                  onImageTap: _openImageSendSheet,
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
            child: GiftSlideStack(slides: _giftSlides, onComboTap: _tapGiftCombo),
          ),
          Positioned(
            right: 18,
            bottom: 52 + MediaQuery.paddingOf(context).bottom,
            child: ComboBuzzer(
              slide: _activeComboSlide,
              onTap: () {
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
    final seats = List<RoomSeat>.generate(spec.totalSeats, (index) => RoomSeat(index: index));

    for (var i = 0; i < mockRoomUsers.length && i < seats.length; i++) {
      seats[i] = RoomSeat(index: i, user: mockRoomUsers[i]);
    }

    return seats;
  }

  void _onSeatTap(int index) {
    final seat = _seats[index];

    if (seat.locked) {
      if (_viewerCanManageRoom) {
        setState(() => _selectedSeatIndex = _selectedSeatIndex == index ? null : index);
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
      setState(() => _selectedSeatIndex = _selectedSeatIndex == index ? null : index);
      return;
    }
  }

  void _onUserTap(int index) {
    final user = _seats[index].user;
    if (user == null) return;
    _openMiniProfile(user, index);
  }

  void _occupySeat(int index) {
    setState(() {
      final oldIndex = _seats.indexWhere((seat) => seat.user?.id == _currentUser.id);
      if (oldIndex >= 0) {
        _seats[oldIndex] = _seats[oldIndex].copyWith(clearUser: true);
      }
      _seats[index] = _seats[index].copyWith(user: _currentUser, locked: false);
      _selectedSeatIndex = null;
    });
  }


  void _applyForSeat(int index) {
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
  }

  void _approveSeatApplication(ChatEntry entry) {
    final seatIndex = entry.seatIndex;
    if (seatIndex == null || seatIndex < 0 || seatIndex >= _seats.length) return;
    if (_seats[seatIndex].user != null || _seats[seatIndex].locked) {
      setState(() {
        final index = _messages.indexOf(entry);
        if (index >= 0) {
          _messages[index] = entry.copyWith(message: '${entry.message} • seat unavailable', applicationApproved: true);
        }
      });
      return;
    }

    final applicant = _allRoomUsers.firstWhere(
      (user) => user.id == entry.senderId,
      orElse: () => _currentUser,
    );

    setState(() {
      _seats[seatIndex] = _seats[seatIndex].copyWith(user: applicant, locked: false);
      final index = _messages.indexOf(entry);
      if (index >= 0) {
        _messages[index] = entry.copyWith(message: '${entry.senderName} approved for seat ${seatIndex + 1}', applicationApproved: true);
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
    final inviteUsers = _allRoomUsers.where((user) => !seatedIds.contains(user.id)).toList();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.58),
        padding: EdgeInsets.fromLTRB(14, 10, 14, MediaQuery.paddingOf(context).bottom + 12),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(width: 42),
            const SizedBox(height: 12),
            Text('Invite to seat ${seatIndex + 1}', style: const TextStyle(color: RoomColors.plum, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            if (inviteUsers.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: RoomColors.pearl, borderRadius: BorderRadius.circular(18), border: Border.all(color: RoomColors.softLine)),
                child: const Text('No available users to invite right now.', style: TextStyle(color: Color(0xFF7B6A86), fontWeight: FontWeight.w800)),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: inviteUsers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, userIndex) {
                    final user = inviteUsers[userIndex];
                    return _SeatInviteUserRow(
                      user: user,
                      onInvite: () {
                        Navigator.pop(context);
                        RoomToast.show(context, 'Invite sent to ${user.name} for seat ${seatIndex + 1}');
                      },
                    );
                  },
                ),
              ),
          ],
        ),
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

  GiftSlide? get _activeComboSlide => _giftSlides.isEmpty ? null : _giftSlides.first;

  void _clearRoomFocus() {
    _messageFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _toggleMic() {
    _clearRoomFocus();
    setState(() {
      _micMuted = !_micMuted;
      final index = _seats.indexWhere((seat) => seat.user?.id == _currentUser.id);
      if (index >= 0) {
        final user = _seats[index].user!;
        _seats[index] = _seats[index].copyWith(user: user.copyWith(selfMuted: _micMuted));
      }
    });
  }

  void _handleJoinRoom() {
    _clearRoomFocus();
    final alreadyRequested = _joinRequestUsers.any((user) => user.id == _currentUser.id);
    if (!alreadyRequested) {
      setState(() => _joinRequestUsers.add(_currentUser));
    }
    _openInfoSheet('Join request sent', 'Your request to become a member of $_roomName has been sent to the room owner/admins.');
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
          currentRoomName: _privacyMode == RoomPrivacyMode.privateVibe ? null : _roomName,
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
      _messages.insert(0, ChatEntry(senderName: _currentUser.name, message: text, vipLevel: _currentUser.vipLevel, sendingLevel: _currentUser.sendingLevel, receivingLevel: _currentUser.receivingLevel));
      _messageController.clear();
    });
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
        onSentRankingTap: () => _openSentRankingsPage(),
        onReceivedRankingTap: () => _openReceivedRankingsPage(),
        onFamilyTap: () => _openFamilyPage(user),
        onRelationshipTap: () => _openLoveAndBondCentre(user),
        onMedalsTap: () => _openMedalsPage(user),
        onMentionTap: () => _mentionUser(user),
        onSetAdminTap: () => _setUserAsAdmin(user.id),
        onLeaveAndLock: () {
          Navigator.pop(context);
          setState(() => _seats[seatIndex] = RoomSeat(index: seatIndex, locked: true));
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
    setState(() => _seats[index] = _seats[index].copyWith(user: user.copyWith(selfMuted: !user.selfMuted)));
  }

  void _toggleAdminMute(String userId) {
    final index = _seats.indexWhere((seat) => seat.user?.id == userId);
    if (index < 0) return;
    final user = _seats[index].user!;
    if (user.selfMuted) {
      RoomToast.show(context, 'User muted themselves. Admin cannot unmute self mute.');
      return;
    }
    setState(() => _seats[index] = _seats[index].copyWith(user: user.copyWith(adminMuted: !user.adminMuted)));
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
        subtitle: '${user.name} is VIP ${user.vipLevel}. VIP benefits, SVIP rules, badges, and recharge progress will connect here.',
        icon: Icons.workspace_premium_rounded,
        cards: [
          RoomActionCard(title: 'Current VIP', value: 'VIP ${user.vipLevel}', icon: Icons.workspace_premium_rounded, color: RoomColors.gold),
          RoomActionCard(title: 'Monthly status', value: user.vipLevel >= 25 ? 'Dynamic avatar unlocked' : 'Recharge to unlock more perks', icon: Icons.auto_awesome_rounded, color: RoomColors.violet),
        ],
      ),
    );
  }

  void _openSendingExperiencePage(SeatUser user) {
    _pushRoomActionPageFromSheet(
      RoomActionPage(
        title: 'Sending Experience',
        subtitle: '${user.name}\'s total sending level progress and monthly coin-send history.',
        icon: Icons.north_east_rounded,
        cards: [
          RoomActionCard(title: 'Send level', value: 'Lv ${user.sendingLevel}', icon: Icons.north_east_rounded, color: RoomColors.violet),
          RoomActionCard(title: 'This month sent', value: compactNumber(user.sentExp), icon: Icons.toll_rounded, color: RoomColors.gold),
        ],
      ),
    );
  }

  void _openReceivingExperiencePage(SeatUser user) {
    _pushRoomActionPageFromSheet(
      RoomActionPage(
        title: 'Receiving Experience',
        subtitle: '${user.name}\'s receiving level progress and monthly received coin history.',
        icon: Icons.favorite_rounded,
        cards: [
          RoomActionCard(title: 'Receive level', value: 'Lv ${user.receivingLevel}', icon: Icons.favorite_rounded, color: RoomColors.coral),
          RoomActionCard(title: 'This month received', value: compactNumber(user.receivedExp), icon: Icons.toll_rounded, color: RoomColors.gold),
        ],
      ),
    );
  }

  void _openSentRankingsPage() {
    _pushRoomActionPageFromSheet(RoomRankingsPage(title: 'Sent Rankings', users: _allRoomUsers, sentRanking: true));
  }

  void _openReceivedRankingsPage() {
    _pushRoomActionPageFromSheet(RoomRankingsPage(title: 'Received Rankings', users: _allRoomUsers, sentRanking: false));
  }

  void _openFamilyPage(SeatUser user) {
    final hasFamily = user.familyName.trim().isNotEmpty;
    _pushRoomActionPageFromSheet(
      RoomActionPage(
        title: hasFamily ? user.familyName : 'Join Family',
        subtitle: hasFamily ? '${user.name}\'s family profile, contribution, family rooms, events, and rankings.' : '${user.name} is not in a family yet. Family discovery and create/join flow will connect here.',
        icon: Icons.groups_rounded,
        cards: [
          RoomActionCard(title: hasFamily ? 'Family name' : 'Status', value: hasFamily ? user.familyName : 'No family joined', icon: Icons.groups_rounded, color: RoomColors.aqua),
          RoomActionCard(title: 'Family events', value: 'Family-vs-family activities and rewards connect here', icon: Icons.emoji_events_rounded, color: RoomColors.gold),
        ],
      ),
    );
  }

  void _openLoveAndBondCentre(SeatUser user) {
    _pushRoomActionPageFromSheet(
      RoomActionPage(
        title: 'Love & Bond Centre',
        subtitle: user.relationshipText.trim().isEmpty ? '${user.name} has no active love or bond relationship yet.' : user.relationshipText,
        icon: Icons.favorite_rounded,
        cards: [
          RoomActionCard(title: 'Relationship', value: user.relationshipText.trim().isEmpty ? 'No love or bonds yet' : user.relationshipText, icon: Icons.favorite_rounded, color: RoomColors.coral),
          RoomActionCard(title: 'Cards', value: 'Relationship cards and bond actions connect here', icon: Icons.style_rounded, color: RoomColors.violet),
        ],
      ),
    );
  }

  void _openMedalsPage(SeatUser user) {
    _pushRoomActionPageFromSheet(
      RoomActionPage(
        title: 'Medals',
        subtitle: '${user.name}\'s earned medals and upcoming achievement badges.',
        icon: Icons.military_tech_rounded,
        cards: [
          RoomActionCard(title: 'Current medals', value: user.medals.isEmpty ? 'No medals yet' : user.medals.join('  '), icon: Icons.military_tech_rounded, color: RoomColors.gold),
          RoomActionCard(title: 'Achievement centre', value: 'Medal progress and rules connect here', icon: Icons.auto_graph_rounded, color: RoomColors.aqua),
        ],
      ),
    );
  }

  void _mentionUser(SeatUser user) {
    Navigator.pop(context);
    final mention = '@${user.name} ';
    final current = _messageController.text;
    _messageController.text = current.endsWith(' ') || current.isEmpty ? '$current$mention' : '$current $mention';
    _messageController.selection = TextSelection.collapsed(offset: _messageController.text.length);
    _clearRoomFocus();
  }

  void _setUserAsAdmin(String userId) {
    Navigator.pop(context);
    setState(() {
      for (var i = 0; i < _seats.length; i++) {
        final user = _seats[i].user;
        if (user?.id == userId) {
          _seats[i] = _seats[i].copyWith(user: user!.copyWith(isRoomAdmin: true, roleLabel: 'Administrator'));
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
          builder: (_) => RoomActionPage(title: title, subtitle: subtitle, icon: icon),
        ),
      );
    });
  }

  void _openImageSendSheet() {
    _clearRoomFocus();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.paddingOf(context).bottom + 14),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(width: 42),
            const SizedBox(height: 12),
            const Text('Send Image', style: TextStyle(color: RoomColors.plum, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _MiniGameChip(icon: Icons.photo_library_rounded, label: 'Gallery', onTap: () => RoomToast.show(context, 'Gallery picker will connect here'))),
                const SizedBox(width: 10),
                Expanded(child: _MiniGameChip(icon: Icons.camera_alt_rounded, label: 'Camera', onTap: () => RoomToast.show(context, 'Camera picker will connect here'))),
              ],
            ),
          ],
        ),
      ),
    );
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
                  final categoryGifts = mockGiftItems.where((gift) => gift.category == category).toList();
                  if (categoryGifts.isNotEmpty) _selectedGift = categoryGifts.first;
                  if (category == GiftCategory.lucky && _selectedCombo < 9) _selectedCombo = 9;
                });
              },
              onGiftSelected: (gift) => setSheetState(() => _selectedGift = gift),
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
              onComboChanged: (combo) => setSheetState(() => _selectedCombo = combo),
              onSend: () {
                Navigator.pop(context);
                _sendGift();
              },
              onRecharge: () => RoomToast.show(context, 'Wallet / coin recharge opened'),
            );
          },
        );
      },
    );
  }

  void _sendGift() {
    final gift = _selectedGift;
    if (gift == null) return;
    final receivers = _roomUsers.where((user) => _selectedReceiverIds.contains(user.id)).toList();
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

    for (final receiver in receivers) {
      final slide = GiftSlide(
        id: '${receiver.id}-${DateTime.now().microsecondsSinceEpoch}',
        senderName: _currentUser.name,
        receiverName: receiver.name,
        giftName: gift.name,
        giftIcon: gift.icon,
        colors: gift.colors,
        combo: _selectedCombo,
        remainingSeconds: 15,
      );
      _startGiftSlide(slide);
      setState(() {
        _messages.insert(0, ChatEntry(senderName: _currentUser.name, message: 'sent ${receiver.name} ${gift.chatSymbol} x$_selectedCombo', vipLevel: _currentUser.vipLevel, sendingLevel: _currentUser.sendingLevel, receivingLevel: _currentUser.receivingLevel, isGift: true));
      });
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
        return;
      }
      setState(() => _giftSlides[index] = active.copyWith(remainingSeconds: active.remainingSeconds - 1));
    });
  }

  void _tapGiftCombo(GiftSlide slide) {
    final index = _giftSlides.indexWhere((item) => item.id == slide.id);
    if (index < 0) return;
    final active = _giftSlides[index];
    setState(() {
      _giftSlides[index] = active.copyWith(combo: active.combo + 1, remainingSeconds: 15);
      _messages.insert(0, ChatEntry(senderName: active.senderName, message: 'sent ${active.receiverName} 🎁 x${active.combo + 1}', vipLevel: _currentUser.vipLevel, sendingLevel: _currentUser.sendingLevel, receivingLevel: _currentUser.receivingLevel, isGift: true));
    });
  }

  void _openInboxSheet() {
    _clearRoomFocus();
    setState(() => _inboxUnreadCount = 0);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.82,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Container(
            color: RoomColors.pearl,
            child: const InboxPage(),
          ),
        ),
      ),
    );
  }

  void _openEmojiTray() {
    _clearRoomFocus();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.fromLTRB(18, 12, 18, MediaQuery.paddingOf(context).bottom + 16),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: ['😍', '😂', '🔥', '👏', '💖', '😎', '🎉', '💎'].map((emoji) {
            return GestureDetector(
              onTap: () {
                Navigator.pop(context);
                RoomToast.show(context, '$emoji reaction will animate over avatar');
              },
              child: Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: RoomColors.pearl, borderRadius: BorderRadius.circular(18), border: Border.all(color: RoomColors.softLine)),
                child: Text(emoji, style: const TextStyle(fontSize: 28)),
              ),
            );
          }).toList(),
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
      builder: (_) => StatefulBuilder(
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
            onAdminsTap: () => _openModulePage('Admins', 'Room administrator management will connect here.', Icons.shield_rounded),
            onAnnouncementTap: _openAnnouncementSheet,
            onInboxTap: _openInboxSheet,
            onJoinRequestsTap: _openJoinRequestsSheet,
            onReportsTap: () => _openModulePage('Reports', 'Room safety, reports, and moderation queue will connect here.', Icons.report_gmailerrorred_rounded),
            onBlockedTap: () => _openModulePage('Blocked users', 'Blocked and restricted room users will connect here.', Icons.block_rounded),
            onEffectsTap: () => _openModulePage('Room effects', 'Room entrance effects, seat effects, and background effects will connect here.', Icons.auto_awesome_rounded),
            onMusicTap: () => _openModulePage('Music', 'Room music controls and playlist will connect here.', Icons.music_note_rounded),
            onToggleRoomImages: (value) {
              setState(() => _roomImagesEnabled = value);
              setSheetState(() {});
            },
            onToggleGuestMessages: (value) {
              setState(() => _guestMessagesEnabled = value);
              setSheetState(() {});
            },
            onToggleApplyOnlyMode: (value) {
              setState(() => _applyOnlyModeEnabled = value);
              setSheetState(() {});
            },
            onCloseRoom: () {
              Navigator.pop(context);
              Navigator.maybePop(context);
            },
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
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.58),
            padding: EdgeInsets.fromLTRB(14, 10, 14, MediaQuery.paddingOf(context).bottom + 12),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetHandle(width: 42),
                const SizedBox(height: 12),
                const Text('Join requests', style: TextStyle(color: RoomColors.plum, fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                if (_joinRequestUsers.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: RoomColors.pearl, borderRadius: BorderRadius.circular(18), border: Border.all(color: RoomColors.softLine)),
                    child: const Text('No pending join requests.', style: TextStyle(color: Color(0xFF7B6A86), fontWeight: FontWeight.w800)),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _joinRequestUsers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final user = _joinRequestUsers[index];
                        return _JoinRequestRow(
                          user: user,
                          onApprove: () {
                            setState(() => _joinRequestUsers.removeWhere((item) => item.id == user.id));
                            setSheetState(() {});
                          },
                          onReject: () {
                            setState(() => _joinRequestUsers.removeWhere((item) => item.id == user.id));
                            setSheetState(() {});
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
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
        onModeChanged: (mode) => setState(() => _privacyMode = mode),
      ),
    );
  }


  void _openGamesSheet() {
    _clearRoomFocus();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.fromLTRB(14, 10, 14, MediaQuery.paddingOf(context).bottom + 12),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const SizedBox(height: 12),
            const Text('Games', style: TextStyle(color: RoomColors.plum, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MiniGameChip(icon: Icons.casino_rounded, label: 'Crystal Hunt', onTap: () => RoomToast.show(context, 'Crystal Hunt opens here')),
                _MiniGameChip(icon: Icons.sports_esports_rounded, label: 'Ludo', onTap: () => RoomToast.show(context, 'Ludo opens here')),
                _MiniGameChip(icon: Icons.grid_4x4_rounded, label: 'Carrom', onTap: () => RoomToast.show(context, 'Carrom opens here')),
                _MiniGameChip(icon: Icons.emoji_events_rounded, label: 'PK', onTap: () => RoomToast.show(context, 'PK game opens here')),
              ],
            ),
          ],
        ),
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
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.fromLTRB(14, 10, 14, MediaQuery.paddingOf(context).bottom + 12),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(width: 42),
            const SizedBox(height: 12),
            const Text('Room Backgrounds', style: TextStyle(color: RoomColors.plum, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            ...mockRoomBackgroundThemes.map(
              (theme) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(color: RoomColors.pearl, borderRadius: BorderRadius.circular(18), border: Border.all(color: RoomColors.softLine)),
                child: ListTile(
                  dense: true,
                  leading: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(gradient: LinearGradient(colors: theme.colors), borderRadius: BorderRadius.circular(12)),
                  ),
                  title: Text(theme.name, style: const TextStyle(color: RoomColors.plum, fontSize: 13, fontWeight: FontWeight.w900)),
                  subtitle: Text(theme.id == _selectedBackgroundTheme.id ? 'Applied now' : 'Owned background', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  trailing: TextButton(
                    onPressed: () {
                      setState(() => _selectedBackgroundTheme = theme);
                      Navigator.pop(context);
                    },
                    child: Text(theme.id == _selectedBackgroundTheme.id ? 'Applied' : 'Apply', style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.storefront_rounded, color: RoomColors.gold),
              title: const Text('Open Theme Store', style: TextStyle(color: RoomColors.plum, fontSize: 13, fontWeight: FontWeight.w900)),
              subtitle: const Text('Purchase more backgrounds', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => RoomToast.show(context, 'Theme store opened'),
            ),
          ],
        ),
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
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Container(
          padding: EdgeInsets.fromLTRB(18, 12, 18, MediaQuery.paddingOf(context).bottom + 16),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              const SizedBox(height: 16),
              const Text('Broad Announcement', style: TextStyle(color: RoomColors.plum, fontSize: 23, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              TextField(
                controller: _announcementController,
                maxLines: 3,
                decoration: InputDecoration(hintText: 'Type announcement...', filled: true, fillColor: RoomColors.pearl, border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none)),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    RoomToast.show(context, 'Announcement saved');
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: RoomColors.plum, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
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
    _clearRoomFocus();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.fromLTRB(18, 12, 18, MediaQuery.paddingOf(context).bottom + 16),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            const SizedBox(height: 16),
            const Text('Leave room?', style: TextStyle(color: RoomColors.plum, fontSize: 23, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('Stay will minimize this chatroom into a floating bubble.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF7B6A86), fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () { Navigator.pop(context); setState(() => _minimized = true); }, child: const Text('Stay'))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(onPressed: () { Navigator.pop(context); Navigator.maybePop(context); }, style: ElevatedButton.styleFrom(backgroundColor: RoomColors.plum, foregroundColor: Colors.white), child: const Text('Leave'))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openInfoSheet(String title, String body) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.fromLTRB(18, 12, 18, MediaQuery.paddingOf(context).bottom + 16),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [const SheetHandle(), const SizedBox(height: 16), Text(title, style: const TextStyle(color: RoomColors.plum, fontSize: 23, fontWeight: FontWeight.w900)), const SizedBox(height: 10), Text(body, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 13, fontWeight: FontWeight.w700))]),
      ),
    );
  }
}



class _JoinRequestRow extends StatelessWidget {
  const _JoinRequestRow({
    required this.user,
    required this.onApprove,
    required this.onReject,
  });

  final SeatUser user;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: RoomColors.pearl, borderRadius: BorderRadius.circular(18), border: Border.all(color: RoomColors.softLine)),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: user.avatarColors)),
            child: Text(avatarLetter(user.name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: RoomColors.plum, fontSize: 13, fontWeight: FontWeight.w900)),
                Text(user.roleLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onReject,
            style: TextButton.styleFrom(foregroundColor: RoomColors.coral, textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
            child: const Text('Reject'),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: onApprove,
            style: TextButton.styleFrom(foregroundColor: RoomColors.aqua, textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }
}

class _SeatInviteUserRow extends StatelessWidget {
  const _SeatInviteUserRow({required this.user, required this.onInvite});

  final SeatUser user;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: RoomColors.pearl, borderRadius: BorderRadius.circular(18), border: Border.all(color: RoomColors.softLine)),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: user.avatarColors)),
            child: Text(avatarLetter(user.name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: RoomColors.plum, fontSize: 13, fontWeight: FontWeight.w900)),
                Text(user.roleLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: onInvite,
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 15),
            label: const Text('Invite'),
            style: TextButton.styleFrom(foregroundColor: RoomColors.aqua, textStyle: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _MiniGameChip extends StatelessWidget {
  const _MiniGameChip({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 138,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(color: const Color(0xFFFCFAF6), borderRadius: BorderRadius.circular(16), border: Border.all(color: RoomColors.softLine)),
        child: Row(children: [
          Icon(icon, color: RoomColors.aqua, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: RoomColors.plum, fontSize: 12, fontWeight: FontWeight.w900))),
        ]),
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.11), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
        child: Row(children: [const Icon(Icons.campaign_rounded, color: RoomColors.gold), const SizedBox(width: 12), const Expanded(child: Text('Weekly Gift Cards are live. Limited cards available for event rewards.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, height: 1.22))), Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)), child: const Text('View', style: TextStyle(color: RoomColors.gold, fontWeight: FontWeight.w900)))]),
      ),
    );
  }
}

class _ShareRoomBanner extends StatelessWidget {
  const _ShareRoomBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: const LinearGradient(colors: [RoomColors.gold, RoomColors.coral])),
        child: const Row(children: [SizedBox(width: 18), CircleAvatar(radius: 15, backgroundColor: Colors.white, child: Icon(Icons.reply_rounded, color: RoomColors.gold)), SizedBox(width: 12), Expanded(child: Text('Share your chat room to invite more friends', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900))), Icon(Icons.chevron_right_rounded, color: Colors.white), SizedBox(width: 14)]),
      ),
    );
  }
}

class _InboxRow extends StatelessWidget {
  const _InboxRow({required this.icon, required this.title, required this.subtitle, required this.color});

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFFCFAF6), borderRadius: BorderRadius.circular(22), border: Border.all(color: RoomColors.softLine)),
      child: Row(children: [CircleAvatar(backgroundColor: color.withValues(alpha: 0.13), child: Icon(icon, color: color)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: RoomColors.plum, fontWeight: FontWeight.w900, fontSize: 13)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: Color(0xFF7B6A86), fontWeight: FontWeight.w700))])), const Icon(Icons.chevron_right_rounded, color: Color(0xFF96899F))]),
    );
  }
}
