import '../../realtime/live_room_realtime_hub.dart';
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
    LiveRoomRealtimeHub.sendSettingsUpdate(<String, dynamic>{
      'action': 'seat_layout_changed',
      'layout_id': nextLayoutId,
    });
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
      LiveRoomRealtimeHub.sendSeatLeave(oldIndex);
    }

    seats[index] = seats[index].copyWith(
      user: currentUser,
      locked: false,
    );

    selectedSeatIndex = null;
    LiveRoomRealtimeHub.sendSeatTake(index);
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

    LiveRoomRealtimeHub.sendSeatApplication(index);
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

    LiveRoomRealtimeHub.sendJoinRequestResolution(
      targetUserId: applicant.id,
      approved: true,
    );
    LiveRoomRealtimeHub.sendSeatTake(seatIndex);
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
    LiveRoomRealtimeHub.sendSettingsUpdate(<String, dynamic>{
      'action': 'seat_locked',
      'seat_index': index,
      'seat_no': index + 1,
    });
    onChanged();
    onToast('Seat ${index + 1} locked');
  }

  void unlockSeat(int index) {
    seats[index] = seats[index].copyWith(locked: false);
    selectedSeatIndex = null;
    LiveRoomRealtimeHub.sendSettingsUpdate(<String, dynamic>{
      'action': 'seat_unlocked',
      'seat_index': index,
      'seat_no': index + 1,
    });
    onChanged();
    onToast('Seat ${index + 1} unlocked');
  }

  void removeUserFromRoom(String userId) {
    var removed = false;

    for (var i = 0; i < seats.length; i++) {
      final user = seats[i].user;
      if (user?.id == userId) {
        seats[i] = seats[i].copyWith(clearUser: true);
        LiveRoomRealtimeHub.sendSeatLeave(i);
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
      LiveRoomRealtimeHub.sendMuteState(
        seatIndex: index,
        muted: micMuted,
        adminMuted: user.adminMuted,
      );
    }

    onChanged();
  }

  void toggleSelfMute(String userId) {
    final index = seats.indexWhere((seat) => seat.user?.id == userId);
    if (index < 0) return;

    final user = seats[index].user!;
    final nextMuted = !user.selfMuted;
    seats[index] = seats[index].copyWith(
      user: user.copyWith(selfMuted: nextMuted),
    );

    LiveRoomRealtimeHub.sendMuteState(
      seatIndex: index,
      muted: nextMuted,
      adminMuted: user.adminMuted,
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

    final nextAdminMuted = !user.adminMuted;
    seats[index] = seats[index].copyWith(
      user: user.copyWith(adminMuted: nextAdminMuted),
    );

    LiveRoomRealtimeHub.sendMuteState(
      seatIndex: index,
      muted: user.selfMuted,
      adminMuted: nextAdminMuted,
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

    LiveRoomRealtimeHub.sendSettingsUpdate(<String, dynamic>{
      'action': 'room_admin_added',
      'user_id': userId,
    });
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

    LiveRoomRealtimeHub.sendSettingsUpdate(<String, dynamic>{
      'action': 'room_admin_removed',
      'user_id': userId,
    });
    onChanged();
  }

  /// Current-user action: leave the mic seat only.
  /// Moderator action on another seated user: clear that user and lock that seat.
  void leaveAndLockSeat(int seatIndex) {
    if (seatIndex < 0 || seatIndex >= seats.length) return;

    final seatedUser = seats[seatIndex].user;
    final isCurrentUserSeat = seatedUser?.id == currentUser.id;

    seats[seatIndex] = RoomSeat(
      index: seatIndex,
      locked: !isCurrentUserSeat,
    );

    selectedSeatIndex = null;
    LiveRoomRealtimeHub.sendSeatLeave(seatIndex);
    if (!isCurrentUserSeat) {
      LiveRoomRealtimeHub.sendSettingsUpdate(<String, dynamic>{
        'action': 'seat_locked_after_leave',
        'seat_index': seatIndex,
        'seat_no': seatIndex + 1,
      });
    }
    onChanged();
    onToast(isCurrentUserSeat ? 'You left the seat' : 'User locked off seat ${seatIndex + 1}');
  }

  /// Moderator action: remove another user from the mic seat without locking it.
  void leaveSeatOnly(int seatIndex) {
    if (seatIndex < 0 || seatIndex >= seats.length) return;

    final seatedUser = seats[seatIndex].user;
    if (seatedUser == null) return;

    seats[seatIndex] = RoomSeat(index: seatIndex);
    selectedSeatIndex = null;
    LiveRoomRealtimeHub.sendSeatLeave(seatIndex);
    onChanged();
    onToast('${seatedUser.name} left seat ${seatIndex + 1}');
  }
}

typedef VoidCallbackLike = void Function();
typedef ValueChangedLike<T> = void Function(T value);
