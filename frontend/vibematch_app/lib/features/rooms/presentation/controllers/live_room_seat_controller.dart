import 'package:flutter/material.dart';

import '../../data/live_room_realtime_bridge.dart';
import '../live_room_models.dart';

class LiveRoomSeatController implements LiveRoomRealtimeSeatApplier {
  LiveRoomSeatController({
    required this.currentUser,
    required this.onChanged,
    required this.onToast,
  }) {
    LiveRoomRealtimeBridge.registerSeatApplier(this);
  }

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

  void dispose() {
    LiveRoomRealtimeBridge.unregisterSeatApplier(this);
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
    _placeUserOnSeat(user: currentUser, seatIndex: index);
    selectedSeatIndex = null;
    onChanged();
    LiveRoomRealtimeBridge.sendSeatOccupy(index);
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

    LiveRoomRealtimeBridge.sendSeatOccupy(seatIndex);
    onChanged();
  }

  void switchSeat(int index) {
    final oldIndex = seats.indexWhere((seat) => seat.user?.id == currentUser.id);
    _placeUserOnSeat(user: currentUser, seatIndex: index);
    selectedSeatIndex = null;
    onChanged();
    onToast('Switched to seat ${index + 1}');

    if (oldIndex >= 0 && oldIndex != index) {
      LiveRoomRealtimeBridge.sendSeatSwitch(
        fromSeatIndex: oldIndex,
        toSeatIndex: index,
      );
    } else {
      LiveRoomRealtimeBridge.sendSeatOccupy(index);
    }
  }

  void lockSeat(int index) {
    seats[index] = seats[index].copyWith(
      locked: true,
      clearUser: true,
    );
    selectedSeatIndex = null;
    onChanged();
    onToast('Seat ${index + 1} locked');
    LiveRoomRealtimeBridge.sendSeatLock(index);
  }

  void unlockSeat(int index) {
    seats[index] = seats[index].copyWith(locked: false);
    selectedSeatIndex = null;
    onChanged();
    onToast('Seat ${index + 1} unlocked');
    LiveRoomRealtimeBridge.sendSeatUnlock(index);
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
    LiveRoomRealtimeBridge.sendSelfMute(micMuted);
  }

  void toggleSelfMute(String userId) {
    final index = seats.indexWhere((seat) => seat.user?.id == userId);
    if (index < 0) return;

    final user = seats[index].user!;
    final muted = !user.selfMuted;
    seats[index] = seats[index].copyWith(
      user: user.copyWith(selfMuted: muted),
    );

    if (userId == currentUser.id) {
      micMuted = muted;
      LiveRoomRealtimeBridge.sendSelfMute(muted);
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

    final muted = !user.adminMuted;
    seats[index] = seats[index].copyWith(
      user: user.copyWith(adminMuted: muted),
    );

    onChanged();
    LiveRoomRealtimeBridge.sendAdminMute(targetUserId: userId, muted: muted);
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
    onChanged();
    onToast(isCurrentUserSeat ? 'You left the seat' : 'User locked off seat ${seatIndex + 1}');

    if (isCurrentUserSeat) {
      LiveRoomRealtimeBridge.sendSeatLeave(seatIndex);
    } else {
      LiveRoomRealtimeBridge.sendSeatLock(seatIndex);
    }
  }

  /// Moderator action: remove another user from the mic seat without locking it.
  void leaveSeatOnly(int seatIndex) {
    if (seatIndex < 0 || seatIndex >= seats.length) return;

    final seatedUser = seats[seatIndex].user;
    if (seatedUser == null) return;

    seats[seatIndex] = RoomSeat(index: seatIndex);
    selectedSeatIndex = null;
    onChanged();
    onToast('${seatedUser.name} left seat ${seatIndex + 1}');
    LiveRoomRealtimeBridge.sendSeatLeave(seatIndex);
  }

  @override
  void applyRemoteSeatOccupy({
    required int seatIndex,
    required String userId,
    required String displayName,
  }) {
    if (!_isValidSeatIndex(seatIndex)) return;
    final user = _resolveRemoteUser(userId: userId, displayName: displayName);
    _placeUserOnSeat(user: user, seatIndex: seatIndex);
    selectedSeatIndex = null;
    onChanged();
  }

  @override
  void applyRemoteSeatLeave({required int seatIndex}) {
    if (!_isValidSeatIndex(seatIndex)) return;
    seats[seatIndex] = seats[seatIndex].copyWith(clearUser: true);
    selectedSeatIndex = null;
    onChanged();
  }

  @override
  void applyRemoteSeatSwitch({
    required int fromSeatIndex,
    required int toSeatIndex,
    required String userId,
    required String displayName,
  }) {
    if (!_isValidSeatIndex(toSeatIndex)) return;
    if (_isValidSeatIndex(fromSeatIndex)) {
      seats[fromSeatIndex] = seats[fromSeatIndex].copyWith(clearUser: true);
    }
    final user = _resolveRemoteUser(userId: userId, displayName: displayName);
    seats[toSeatIndex] = seats[toSeatIndex].copyWith(user: user, locked: false);
    selectedSeatIndex = null;
    onChanged();
  }

  @override
  void applyRemoteSeatLock({required int seatIndex}) {
    if (!_isValidSeatIndex(seatIndex)) return;
    seats[seatIndex] = seats[seatIndex].copyWith(locked: true, clearUser: true);
    selectedSeatIndex = null;
    onChanged();
  }

  @override
  void applyRemoteSeatUnlock({required int seatIndex}) {
    if (!_isValidSeatIndex(seatIndex)) return;
    seats[seatIndex] = seats[seatIndex].copyWith(locked: false);
    selectedSeatIndex = null;
    onChanged();
  }

  @override
  void applyRemoteSelfMute({
    required String userId,
    required bool muted,
  }) {
    final index = seats.indexWhere((seat) => seat.user?.id == userId);
    if (index < 0) return;
    final user = seats[index].user!;
    seats[index] = seats[index].copyWith(user: user.copyWith(selfMuted: muted));
    if (userId == currentUser.id) micMuted = muted;
    onChanged();
  }

  @override
  void applyRemoteAdminMute({
    required String userId,
    required bool muted,
  }) {
    final index = seats.indexWhere((seat) => seat.user?.id == userId);
    if (index < 0) return;
    final user = seats[index].user!;
    seats[index] = seats[index].copyWith(user: user.copyWith(adminMuted: muted));
    onChanged();
  }

  @override
  void applyRemoteRoomStateSnapshot(Map<String, dynamic> payload) {
    final remoteSeats = payload['seats'];
    if (remoteSeats is! List || remoteSeats.isEmpty) return;

    for (final item in remoteSeats) {
      if (item is! Map<String, dynamic>) continue;

      final seatIndex = _intValue(item['seat_index']);
      if (!_isValidSeatIndex(seatIndex)) continue;

      final locked = _boolValue(item['locked']);
      final userPayload = item['user'];
      SeatUser? user;

      if (userPayload is Map<String, dynamic>) {
        final userId = userPayload['user_id']?.toString() ?? '';
        final displayName = userPayload['display_name']?.toString() ?? '';
        if (userId.trim().isNotEmpty) {
          user = _resolveRemoteUser(userId: userId, displayName: displayName)
              .copyWith(
            selfMuted: _boolValue(userPayload['self_muted']),
            adminMuted: _boolValue(userPayload['admin_muted']),
          );
        }
      }

      seats[seatIndex] = RoomSeat(
        index: seatIndex,
        locked: locked,
        user: user,
      );
    }

    micMuted = seats.any(
      (seat) => seat.user?.id == currentUser.id && seat.user!.selfMuted,
    );
    selectedSeatIndex = null;
    onChanged();
  }

  void _placeUserOnSeat({
    required SeatUser user,
    required int seatIndex,
  }) {
    if (!_isValidSeatIndex(seatIndex)) return;

    final oldIndex = seats.indexWhere((seat) => seat.user?.id == user.id);
    if (oldIndex >= 0) {
      seats[oldIndex] = seats[oldIndex].copyWith(clearUser: true);
    }

    seats[seatIndex] = seats[seatIndex].copyWith(user: user, locked: false);
  }

  SeatUser _resolveRemoteUser({
    required String userId,
    required String displayName,
  }) {
    for (final seat in seats) {
      final user = seat.user;
      if (user?.id == userId) return user!;
    }

    for (final user in mockRoomUsers) {
      if (user.id == userId) return user;
    }

    for (final user in mockInviteUsers) {
      if (user.id == userId) return user;
    }

    return SeatUser(
      id: userId,
      name: displayName.trim().isEmpty ? 'Guest' : displayName,
      roleLabel: 'Member',
      familyName: '',
      relationshipText: '',
      vipLevel: 0,
      sendingLevel: 0,
      receivingLevel: 0,
      sentExp: 0,
      receivedExp: 0,
      medals: const [],
      avatarColors: const [
        Color(0xFF18C7B7),
        Color(0xFF6C63FF),
      ],
      isCurrentUser: userId == currentUser.id,
    );
  }

  int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? -1;
  }

  bool _boolValue(Object? value) {
    if (value is bool) return value;
    return value?.toString().toLowerCase() == 'true';
  }

  bool _isValidSeatIndex(int index) => index >= 0 && index < seats.length;
}

typedef VoidCallbackLike = void Function();
typedef ValueChangedLike<T> = void Function(T value);
