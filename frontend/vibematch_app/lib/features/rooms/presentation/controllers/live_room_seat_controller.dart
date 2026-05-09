import '../../data/live_room_media_signaling_service.dart';
import '../live_room_models.dart';

class LiveRoomSeatController {
  LiveRoomSeatController({
    required SeatUser currentUser,
    required this.onChanged,
    required this.onToast,
  }) : currentUser = LiveRoomMediaSignalingService.instance.effectiveCurrentUser(currentUser);

  final SeatUser currentUser;
  final VoidCallbackLike onChanged;
  final ValueChangedLike<String> onToast;

  String layoutId = '5x2';
  int? selectedSeatIndex;
  bool micMuted = false;
  List<RoomSeat> seats = <RoomSeat>[];

  final Map<String, DateTime> _seatApplyCooldownUntil = <String, DateTime>{};

  List<SeatUser> get roomUsers {
    return seats.where((seat) => seat.user != null).map((seat) => seat.user!).toList();
  }

  void initialize(String initialLayoutId) {
    layoutId = initialLayoutId;
    seats = buildSeatsForLayout(layoutId);
    LiveRoomMediaSignalingService.instance.joinRoom(currentUser: currentUser);
  }

  List<RoomSeat> buildSeatsForLayout(String targetLayoutId) {
    final spec = SeatLayoutSpec.parse(targetLayoutId);
    final builtSeats = List<RoomSeat>.generate(spec.totalSeats, (index) => RoomSeat(index: index));

    for (var i = 0; i < mockRoomUsers.length && i < builtSeats.length; i++) {
      final mockUser = mockRoomUsers[i];
      if (mockUser.id == 'founder_owner' && currentUser.id != 'founder_owner') {
        builtSeats[i] = RoomSeat(index: i, user: currentUser);
      } else if (mockUser.id == currentUser.id) {
        builtSeats[i] = RoomSeat(index: i, user: currentUser);
      } else {
        builtSeats[i] = RoomSeat(index: i, user: mockUser);
      }
    }

    final alreadyVisible = builtSeats.any((seat) => seat.user?.id == currentUser.id);
    if (!alreadyVisible && builtSeats.isNotEmpty) {
      builtSeats[0] = RoomSeat(index: 0, user: currentUser);
    }

    return builtSeats;
  }

  void changeLayout(String nextLayoutId) {
    final seatedUsers = roomUsers;
    layoutId = nextLayoutId;
    seats = List<RoomSeat>.generate(SeatLayoutSpec.parse(nextLayoutId).totalSeats, (index) => RoomSeat(index: index));

    for (var i = 0; i < seatedUsers.length && i < seats.length; i++) {
      seats[i] = seats[i].copyWith(user: seatedUsers[i]);
    }

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
    final oldIndex = seats.indexWhere((seat) => seat.user?.id == currentUser.id);
    final userToMove = oldIndex >= 0 ? seats[oldIndex].user! : currentUser.copyWith(selfMuted: micMuted);

    if (oldIndex >= 0) {
      seats[oldIndex] = seats[oldIndex].copyWith(clearUser: true);
    }

    seats[index] = seats[index].copyWith(user: userToMove.copyWith(selfMuted: micMuted || userToMove.selfMuted), locked: false);
    selectedSeatIndex = null;
    LiveRoomMediaSignalingService.instance.takeSeat(index);
    LiveRoomMediaSignalingService.instance.setMicEnabled(!micMuted);
    onChanged();
  }

  bool inviteUserToSeat({required int seatIndex, required SeatUser invitedUser}) {
    if (seatIndex < 0 || seatIndex >= seats.length) {
      onToast('Seat unavailable');
      return false;
    }

    if (seats[seatIndex].locked || seats[seatIndex].user != null) {
      onToast('Seat ${seatIndex + 1} is no longer available');
      return false;
    }

    final oldIndex = seats.indexWhere((seat) => seat.user?.id == invitedUser.id);
    final userToMove = oldIndex >= 0 ? seats[oldIndex].user! : invitedUser;

    if (oldIndex >= 0) {
      seats[oldIndex] = seats[oldIndex].copyWith(clearUser: true);
    }

    seats[seatIndex] = seats[seatIndex].copyWith(user: userToMove, locked: false);
    selectedSeatIndex = null;
    onChanged();
    onToast('${invitedUser.name} accepted seat ${seatIndex + 1} invite');
    return true;
  }

  void applyForSeat({required int index, required List<ChatEntry> messages}) {
    final now = DateTime.now();
    final cooldownUntil = _seatApplyCooldownUntil[currentUser.id];
    if (cooldownUntil != null && cooldownUntil.isAfter(now)) {
      final secondsLeft = cooldownUntil.difference(now).inSeconds.clamp(1, 20);
      onToast('You can reapply in ${secondsLeft}s');
      return;
    }

    final alreadyApplied = messages.any((message) => message.isSeatApplication && !message.applicationResolved && message.senderId == currentUser.id);
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
        message: 'wants to join the mic',
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

  void approveSeatApplication({required ChatEntry entry, required List<ChatEntry> messages, required List<SeatUser> allRoomUsers}) {
    final seatIndex = entry.seatIndex;
    if (seatIndex == null || seatIndex < 0 || seatIndex >= seats.length) return;
    if (entry.applicationResolved) return;

    if (seats[seatIndex].user != null || seats[seatIndex].locked) {
      final index = messages.indexOf(entry);
      if (index >= 0) {
        messages[index] = entry.copyWith(message: '${entry.senderName} seat request expired', applicationApproved: true);
      }
      onChanged();
      return;
    }

    final applicant = allRoomUsers.firstWhere((user) => user.id == entry.senderId, orElse: () => currentUser);
    final oldIndex = seats.indexWhere((seat) => seat.user?.id == applicant.id);
    final applicantToMove = oldIndex >= 0 ? seats[oldIndex].user! : applicant;
    if (oldIndex >= 0) seats[oldIndex] = seats[oldIndex].copyWith(clearUser: true);

    seats[seatIndex] = seats[seatIndex].copyWith(user: applicantToMove, locked: false);
    if (applicant.id == currentUser.id) {
      LiveRoomMediaSignalingService.instance.takeSeat(seatIndex);
      LiveRoomMediaSignalingService.instance.setMicEnabled(!micMuted);
    }

    final index = messages.indexOf(entry);
    if (index >= 0) {
      messages[index] = entry.copyWith(message: '${entry.senderName} joined the mic', applicationApproved: true);
    }

    onChanged();
  }

  void rejectSeatApplication({required ChatEntry entry, required List<ChatEntry> messages}) {
    if (!entry.isSeatApplication || entry.applicationResolved) return;

    final index = messages.indexOf(entry);
    if (index < 0) return;

    if (entry.senderId != null) {
      _seatApplyCooldownUntil[entry.senderId!] = DateTime.now().add(const Duration(seconds: 20));
    }

    messages[index] = entry.copyWith(message: '${entry.senderName} seat request rejected', applicationRejected: true);
    onChanged();
    onToast('${entry.senderName} can reapply after 20 seconds');
  }

  void switchSeat(int index) {
    occupySeat(index);
    onToast('Switched to seat ${index + 1}');
  }

  void lockSeat(int index) {
    seats[index] = seats[index].copyWith(locked: true, clearUser: true);
    selectedSeatIndex = null;
    if (seats.indexWhere((seat) => seat.user?.id == currentUser.id) < 0) {
      LiveRoomMediaSignalingService.instance.leaveSeat();
      LiveRoomMediaSignalingService.instance.setMicEnabled(false);
    }
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
      if (userId == currentUser.id) {
        LiveRoomMediaSignalingService.instance.leaveSeat();
        LiveRoomMediaSignalingService.instance.setMicEnabled(false);
      }
      onChanged();
    }
  }

  void toggleMic() {
    micMuted = !micMuted;
    final index = seats.indexWhere((seat) => seat.user?.id == currentUser.id);

    if (index >= 0) {
      final user = seats[index].user!;
      seats[index] = seats[index].copyWith(user: user.copyWith(selfMuted: micMuted));
    }

    LiveRoomMediaSignalingService.instance.setMicEnabled(!micMuted && index >= 0);
    onChanged();
  }

  void toggleSelfMute(String userId) {
    final index = seats.indexWhere((seat) => seat.user?.id == userId);
    if (index < 0) return;

    final user = seats[index].user!;
    final nextMuted = !user.selfMuted;
    seats[index] = seats[index].copyWith(user: user.copyWith(selfMuted: nextMuted));

    if (userId == currentUser.id) {
      micMuted = nextMuted;
      LiveRoomMediaSignalingService.instance.setMicEnabled(!micMuted);
    }

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
    seats[index] = seats[index].copyWith(user: user.copyWith(adminMuted: nextAdminMuted));
    if (userId == currentUser.id) {
      LiveRoomMediaSignalingService.instance.setMicEnabled(!nextAdminMuted && !micMuted);
    }
    onChanged();
  }

  void setUserAsAdmin(String userId) {
    for (var i = 0; i < seats.length; i++) {
      final user = seats[i].user;
      if (user?.id == userId) {
        seats[i] = seats[i].copyWith(user: user!.copyWith(isRoomAdmin: true, roleLabel: 'Administrator'));
      }
    }
    onChanged();
  }

  void removeUserAsAdmin(String userId) {
    for (var i = 0; i < seats.length; i++) {
      final user = seats[i].user;
      if (user?.id == userId && !user!.isHost) {
        seats[i] = seats[i].copyWith(user: user.copyWith(isRoomAdmin: false, roleLabel: 'Member'));
      }
    }
    onChanged();
  }

  void leaveAndLockSeat(int seatIndex) {
    if (seatIndex < 0 || seatIndex >= seats.length) return;

    final seatedUser = seats[seatIndex].user;
    final isCurrentUserSeat = seatedUser?.id == currentUser.id;
    seats[seatIndex] = RoomSeat(index: seatIndex, locked: !isCurrentUserSeat);
    selectedSeatIndex = null;

    if (isCurrentUserSeat) {
      LiveRoomMediaSignalingService.instance.leaveSeat();
      LiveRoomMediaSignalingService.instance.setMicEnabled(false);
    }

    onChanged();
    onToast(isCurrentUserSeat ? 'You left the seat' : 'User locked off seat ${seatIndex + 1}');
  }

  void leaveSeatOnly(int seatIndex) {
    if (seatIndex < 0 || seatIndex >= seats.length) return;

    final seatedUser = seats[seatIndex].user;
    if (seatedUser == null) return;

    seats[seatIndex] = RoomSeat(index: seatIndex);
    selectedSeatIndex = null;

    if (seatedUser.id == currentUser.id) {
      LiveRoomMediaSignalingService.instance.leaveSeat();
      LiveRoomMediaSignalingService.instance.setMicEnabled(false);
    }

    onChanged();
    onToast('${seatedUser.name} left seat ${seatIndex + 1}');
  }
}

typedef VoidCallbackLike = void Function();
typedef ValueChangedLike<T> = void Function(T value);
