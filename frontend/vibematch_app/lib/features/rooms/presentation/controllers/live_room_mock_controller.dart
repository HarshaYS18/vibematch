import 'dart:async';

import '../live_room_models.dart';
import '../widgets/room_theme.dart';

class LiveRoomMockController {
  LiveRoomMockController({
    required this.initialRoomName,
    required this.initialRoomId,
    required this.initialModeTitle,
    required this.initialOnlineCount,
  }) {
    roomName = initialRoomName;
    roomId = initialRoomId;
    privacyMode = privacyModeFromTitle(initialModeTitle);
    messages = List<ChatEntry>.from(mockChatEntries);
    seats = buildSeatsForLayout(layoutId);
    if (roomUsers.isNotEmpty) selectedReceiverIds.add(roomUsers.first.id);
  }

  final String initialRoomName;
  final String initialRoomId;
  final String initialModeTitle;
  final int initialOnlineCount;

  late String roomName;
  late String roomId;
  late RoomPrivacyMode privacyMode;
  late List<RoomSeat> seats;
  late List<ChatEntry> messages;

  String layoutId = '5x2';
  int? selectedSeatIndex;
  bool roomImagesEnabled = true;
  bool guestMessagesEnabled = true;
  bool micMuted = false;
  bool applyOnlyModeEnabled = false;
  int coinBalance = 35494;
  int inboxUnreadCount = 4;
  RoomBackgroundTheme selectedBackgroundTheme = defaultRoomBackgroundTheme;

  GiftCategory selectedGiftCategory = GiftCategory.classic;
  GiftItem? selectedGift = mockGiftItems.first;
  final Set<String> selectedReceiverIds = <String>{};
  int selectedCombo = 1;
  final List<GiftSlide> giftSlides = <GiftSlide>[];
  final Map<String, Timer> giftTimers = <String, Timer>{};

  final SeatUser currentUser = mockRoomUsers.first;
  final List<SeatUser> joinRequestUsers = <SeatUser>[mockInviteUsers[0], mockInviteUsers[1]];

  List<SeatUser> get roomUsers => seats.where((seat) => seat.user != null).map((seat) => seat.user!).toList();

  List<SeatUser> get allRoomUsers {
    final users = <SeatUser>[];
    final ids = <String>{};
    for (final user in mockRoomUsers) {
      if (ids.add(user.id)) users.add(user);
    }
    for (final user in roomUsers) {
      if (ids.add(user.id)) users.add(user);
    }
    for (final user in mockInviteUsers) {
      if (ids.add(user.id)) users.add(user);
    }
    return users;
  }

  bool get viewerCanManageRoom => currentUser.isHost || currentUser.isRoomAdmin;

  int get safeOnlineCount => initialOnlineCount > allRoomUsers.length ? initialOnlineCount : allRoomUsers.length;

  GiftSlide? get activeComboSlide => giftSlides.isEmpty ? null : giftSlides.first;

  List<RoomSeat> buildSeatsForLayout(String targetLayoutId) {
    final spec = SeatLayoutSpec.parse(targetLayoutId);
    final builtSeats = List<RoomSeat>.generate(spec.totalSeats, (index) => RoomSeat(index: index));
    for (var i = 0; i < mockRoomUsers.length && i < builtSeats.length; i++) {
      builtSeats[i] = RoomSeat(index: i, user: mockRoomUsers[i]);
    }
    return builtSeats;
  }

  void dispose() {
    for (final timer in giftTimers.values) {
      timer.cancel();
    }
  }
}
