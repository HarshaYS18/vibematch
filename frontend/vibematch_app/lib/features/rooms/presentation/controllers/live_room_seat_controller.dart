import '../live_room_models.dart';

class LiveRoomSeatController {
  LiveRoomSeatController({
    required this.currentUser,
    required this.onChanged,
    required this.onToast,
  });

  final SeatUser currentUser;
  final VoidCallbackLike onChanged;
  final ValueChangedLike<String> onToast;

  String layoutId = '5x2';
  int? selectedSeatIndex;
  bool micMuted = false;
  List<RoomSeat> seats = <RoomSeat>[];

  List<SeatUser> get roomUsers {
    return seats
        .where((seat) => seat.user != null)
        .map((seat) => seat.user!)
        .toList();
  }

  void initialize(String initialLayoutId) {
    layoutId = initialLayoutId;
    seats = buildSeatsForLayout(layoutId);
  }

  List<RoomSeat> buildSeatsForLayout(String targetLayoutId) {
    final spec = SeatLayoutSpec.parse(targetLayoutId);
    final builtSeats = List<RoomSeat>.generate(
      spec.totalSeats,
      (index) => RoomSeat(index: index),
    );

    for (var i = 0; i < mockRoomUsers.length && i < builtSeats.length; i++) {
      builtSeats[i] = RoomSeat(index: i, user: mockRoomUsers[i]);
    }

    return builtSeats;
  }

  void changeLayout(String nextLayoutId) {
    layoutId = nextLayoutId;
    seats = buildSeatsForLayout(nextLayoutId);
    selectedSeatIndex = null;
    onChanged();
  }

  void toggleSelectedSeat(int index) {
    selectedSeatIndex = selectedSeatIndex == index ? null : index;
    onChanged();
  }

  void clearSelectedSeat() {
    selectedSeatIndex = null;
    onChanged();
  }

  void occupySeat(int index) {
    final oldIndex = seats.indexWhere(
      (seat) => seat.user?.id == currentUser.id,
    );

    if (oldIndex >= 0) {
      seats[oldIndex] = seats[oldIndex].copyWith(clearUser: true);
    }

    seats[index] = seats[index].copyWith(
      user: currentUser,
      locked: false,
    );

    selectedSeatIndex = null;
    onChanged();
  }

  void applyForSeat({
    required int index,
    required List<ChatEntry> messages,
  }) {
    final alreadyApplied = messages.any(
      (message) =>
          message.isSeatApplication &&
          !message.applicationApproved &&
          message.senderId == currentUser.id &&
          message.seatIndex == index,
    );

    if (alreadyApplied) {
      onToast('Seat application already sent');
      return;
    }

    selectedSeatIndex = null;

    messages.insert(
      0,
      ChatEntry(
        senderName: currentUser.name,
        senderId: currentUser.id,
        message: 'applied for seat ${index + 1}',
        vipLevel: currentUser.vipLevel,
        sendingLevel: currentUser.sendingLevel,
        receivingLevel: currentUser.receivingLevel,
        isSeatApplication: true,
        seatIndex: index,
      ),
    );

    onChanged();
    onToast('Seat application sent');
  }

  void approveSeatApplication({
    required ChatEntry entry,
    required List<ChatEntry> messages,
    required List<SeatUser> allRoomUsers,
  }) {
    final seatIndex = entry.seatIndex;
    if (seatIndex == null || seatIndex < 0 || seatIndex >= seats.length) {
      return;
    }

    if (seats[seatIndex].user != null || seats[seatIndex].locked) {
      final index = messages.indexOf(entry);
      if (index >= 0) {
        messages[index] = entry.copyWith(
          message: '${entry.message} • seat unavailable',
          applicationApproved: true,
        );
      }
      onChanged();
      return;
    }

    final applicant = allRoomUsers.firstWhere(
      (user) => user.id == entry.senderId,
      orElse: () => currentUser,
    );

    seats[seatIndex] = seats[seatIndex].copyWith(
      user: applicant,
      locked: false,
    );

    final index = messages.indexOf(entry);
    if (index >= 0) {
      messages[index] = entry.copyWith(
        message: '${entry.senderName} approved for seat ${seatIndex + 1}',
        applicationApproved: true,
      );
    }

    onChanged();
  }

  void switchSeat(int index) {
    occupySeat(index);
    onToast('Switched to seat ${index + 1}');
  }

  void lockSeat(int index) {
    seats[index] = seats[index].copyWith(
      locked: true,
      clearUser: true,
    );
    selectedSeatIndex = null;
    onChanged();
    onToast('Seat ${index + 1} locked');
  }

  void unlockSeat(int index) {
    seats[index] = seats[index].copyWith(locked: false);
    selectedSeatIndex = null;
    onChanged();
    onToast('Seat ${index + 1} unlocked');
  }

  void removeUserFromRoom(String userId) {
    var removed = false;

    for (var i = 0; i < seats.length; i++) {
      final user = seats[i].user;
      if (user?.id == userId) {
        seats[i] = seats[i].copyWith(clearUser: true);
        removed = true;
      }
    }

    if (removed) {
      selectedSeatIndex = null;
      onChanged();
    }
  }

  void toggleMic() {
    micMuted = !micMuted;

    final index = seats.indexWhere(
      (seat) => seat.user?.id == currentUser.id,
    );

    if (index >= 0) {
      final user = seats[index].user!;
      seats[index] = seats[index].copyWith(
        user: user.copyWith(selfMuted: micMuted),
      );
    }

    onChanged();
  }

  void toggleSelfMute(String userId) {
    final index = seats.indexWhere((seat) => seat.user?.id == userId);
    if (index < 0) return;

    final user = seats[index].user!;
    seats[index] = seats[index].copyWith(
      user: user.copyWith(selfMuted: !user.selfMuted),
    );

    onChanged();
  }

  void toggleAdminMute(String userId) {
    final index = seats.indexWhere((seat) => seat.user?.id == userId);
    if (index < 0) return;

    final user = seats[index].user!;

    if (user.selfMuted) {
      onToast('User muted themselves. Admin cannot unmute self mute.');
      return;
    }

    seats[index] = seats[index].copyWith(
      user: user.copyWith(adminMuted: !user.adminMuted),
    );

    onChanged();
  }

  void setUserAsAdmin(String userId) {
    for (var i = 0; i < seats.length; i++) {
      final user = seats[i].user;
      if (user?.id == userId) {
        seats[i] = seats[i].copyWith(
          user: user!.copyWith(
            isRoomAdmin: true,
            roleLabel: 'Administrator',
          ),
        );
      }
    }

    onChanged();
  }

  void removeUserAsAdmin(String userId) {
    for (var i = 0; i < seats.length; i++) {
      final user = seats[i].user;
      if (user?.id == userId && !user!.isHost) {
        seats[i] = seats[i].copyWith(
          user: user.copyWith(
            isRoomAdmin: false,
            roleLabel: 'Member',
          ),
        );
      }
    }

    onChanged();
  }

  void leaveAndLockSeat(int seatIndex) {
    if (seatIndex < 0 || seatIndex >= seats.length) return;

    seats[seatIndex] = RoomSeat(
      index: seatIndex,
      locked: true,
    );

    onChanged();
  }
}

typedef VoidCallbackLike = void Function();
typedef ValueChangedLike<T> = void Function(T value);
