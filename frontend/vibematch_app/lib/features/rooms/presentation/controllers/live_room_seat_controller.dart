import 'package:flutter/material.dart';

import '../../data/live_room_audio_service.dart';
import '../../data/live_room_media_signaling_service.dart';
import '../live_room_models.dart';

class LiveRoomSeatController {
  LiveRoomSeatController({required SeatUser currentUser, required this.onChanged, required this.onToast})
      : currentUser = LiveRoomMediaSignalingService.instance.effectiveCurrentUser(currentUser) {
    LiveRoomMediaSignalingService.instance.roomSnapshot.addListener(_applyLatestMediaSnapshot);
  }

  final SeatUser currentUser;
  final VoidCallbackLike onChanged;
  final ValueChangedLike<String> onToast;

  String layoutId = '5x2';
  int? selectedSeatIndex;
  bool micMuted = false;
  List<RoomSeat> seats = <RoomSeat>[];

  final Map<String, DateTime> _seatApplyCooldownUntil = <String, DateTime>{};

  List<SeatUser> get roomUsers => seats.where((seat) => seat.user != null).map((seat) => seat.user!).toList();

  bool get _currentUserIsOwner => _isOwner(currentUser);
  bool get _currentUserIsAdminOrOwner => _isOwner(currentUser) || currentUser.isRoomAdmin;

  void dispose() {
    LiveRoomMediaSignalingService.instance.roomSnapshot.removeListener(_applyLatestMediaSnapshot);
  }

  void initialize(String initialLayoutId) {
    layoutId = initialLayoutId;
    seats = buildSeatsForLayout(layoutId);
    _applyLatestMediaSnapshot();
    LiveRoomMediaSignalingService.instance.joinRoom(currentUser: currentUser);
    final roomId = LiveRoomMediaSignalingService.instance.roomId;
    if (roomId != null && roomId.trim().isNotEmpty) {
      LiveRoomAudioService.instance.joinRoom(roomId: roomId, currentUser: currentUser);
    }
    Future<void>.microtask(_applyLatestMediaSnapshot);
  }

  List<RoomSeat> buildSeatsForLayout(String targetLayoutId) {
    final spec = SeatLayoutSpec.parse(targetLayoutId);
    return List<RoomSeat>.generate(spec.totalSeats, (index) => RoomSeat(index: index));
  }

  void _applyLatestMediaSnapshot() {
    final snapshot = LiveRoomMediaSignalingService.instance.roomSnapshot.value;
    if (snapshot == null || seats.isEmpty) return;

    final nextSeats = List<RoomSeat>.generate(
      seats.length,
      (index) => RoomSeat(index: index, locked: snapshot.lockedSeatIndexes.contains(index)),
    );
    final usedSeatIndexes = <int>{};

    for (final peer in snapshot.peers) {
      final seatIndex = peer.seatIndex;
      if (seatIndex == null || seatIndex < 0 || seatIndex >= nextSeats.length) continue;
      if (usedSeatIndexes.contains(seatIndex)) continue;

      final isLocalUser = peer.userId == currentUser.id;
      final existingUser = _findKnownSeatUser(peer.userId);
      final seatUser = (isLocalUser ? currentUser : existingUser).copyWith(
        selfMuted: !peer.micEnabled,
        adminMuted: peer.adminMuted,
      );
      nextSeats[seatIndex] = nextSeats[seatIndex].copyWith(
        user: seatUser,
        locked: snapshot.lockedSeatIndexes.contains(seatIndex),
      );
      usedSeatIndexes.add(seatIndex);
    }

    seats = nextSeats;
    final localSeat = seats.firstWhereOrNull((seat) => seat.user?.id == currentUser.id);
    micMuted = localSeat?.user?.selfMuted ?? micMuted;
    if (selectedSeatIndex != null && selectedSeatIndex! >= 0 && selectedSeatIndex! < seats.length) {
      final selectedSeat = seats[selectedSeatIndex!];
      if (selectedSeat.user != null) selectedSeatIndex = null;
    }
    onChanged();
  }

  SeatUser _findKnownSeatUser(String userId) {
    final existing = roomUsers.firstWhereOrNull((user) => user.id == userId);
    if (existing != null) return existing;

    if (_isFounderId(userId)) {
      return const SeatUser(
        id: 'user_6922022',
        name: 'Founder Owner',
        roleLabel: 'Channel Host',
        familyName: '',
        relationshipText: '',
        vipLevel: 32,
        svipLevel: 3,
        sendingLevel: 52,
        receivingLevel: 44,
        sentExp: 0,
        receivedExp: 0,
        medals: [],
        avatarColors: [Color(0xFFFFC857), Color(0xFFE84C72)],
        isHost: true,
        isRoomAdmin: true,
      );
    }

    return SeatUser(
      id: userId,
      name: _displayNameForUserId(userId),
      roleLabel: 'Member',
      familyName: '',
      relationshipText: '',
      vipLevel: 1,
      sendingLevel: 1,
      receivingLevel: 1,
      sentExp: 0,
      receivedExp: 0,
      medals: const [],
      avatarColors: const [Color(0xFF12C7B7), Color(0xFF6D5DF6)],
    );
  }

  String _displayNameForUserId(String userId) {
    if (_isFounderId(userId)) return 'Founder Owner';
    if (userId.startsWith('user_6418')) return 'Google Tester';
    return userId.replaceFirst('user_', 'User ');
  }

  bool _isFounderId(String userId) => userId == 'user_6922022' || userId == 'founder_owner';

  bool _isOwner(SeatUser user) {
    final role = user.roleLabel.toLowerCase();
    return user.isHost || _isFounderId(user.id) || role.contains('owner') || role.contains('channel host') || role.contains('host');
  }

  bool _isAdmin(SeatUser user) {
    final role = user.roleLabel.toLowerCase();
    return user.isRoomAdmin || role.contains('admin') || role.contains('administrator');
  }

  bool _canAdminMuteTarget(SeatUser target) {
    if (!_currentUserIsAdminOrOwner) return false;
    if (target.id == currentUser.id) return false;
    if (_isOwner(target)) return false;
    if (!_currentUserIsOwner && _isAdmin(target)) return false;
    return true;
  }

  bool _canRemoveTarget(SeatUser target) {
    if (!_currentUserIsAdminOrOwner) return false;
    if (target.id == currentUser.id) return false;
    if (_isOwner(target)) return false;
    if (!_currentUserIsOwner && _isAdmin(target)) return false;
    return true;
  }

  void changeLayout(String nextLayoutId) {
    final existingUsers = roomUsers;
    layoutId = nextLayoutId;
    seats = List<RoomSeat>.generate(SeatLayoutSpec.parse(nextLayoutId).totalSeats, (index) => RoomSeat(index: index));
    for (var i = 0; i < existingUsers.length && i < seats.length; i++) {
      seats[i] = seats[i].copyWith(user: existingUsers[i]);
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
    if (index < 0 || index >= seats.length) return;
    final oldIndex = seats.indexWhere((seat) => seat.user?.id == currentUser.id);
    final userToMove = oldIndex >= 0 ? seats[oldIndex].user! : currentUser.copyWith(selfMuted: micMuted);
    if (oldIndex >= 0) seats[oldIndex] = seats[oldIndex].copyWith(clearUser: true);
    seats[index] = seats[index].copyWith(user: userToMove.copyWith(selfMuted: micMuted || userToMove.selfMuted), locked: false);
    selectedSeatIndex = null;
    LiveRoomMediaSignalingService.instance.takeSeat(index);
    LiveRoomMediaSignalingService.instance.setMicEnabled(!micMuted);
    LiveRoomAudioService.instance.takeSeat(index);
    LiveRoomAudioService.instance.setSelfMuted(micMuted);
    onChanged();
  }

  bool inviteUserToSeat({required int seatIndex, required SeatUser invitedUser}) {
    if (!_currentUserIsAdminOrOwner) {
      onToast('Only the owner or room admins can invite users to seats');
      return false;
    }
    if (seatIndex < 0 || seatIndex >= seats.length || seats[seatIndex].locked || seats[seatIndex].user != null) return false;
    if (invitedUser.id == currentUser.id) {
      onToast('You cannot invite yourself to a seat');
      return false;
    }
    selectedSeatIndex = null;
    onChanged();
    return true;
  }

  void applyForSeat({required int index, required List<ChatEntry> messages}) {
    final now = DateTime.now();
    final cooldownUntil = _seatApplyCooldownUntil[currentUser.id];
    if (cooldownUntil != null && cooldownUntil.isAfter(now)) return;
    final alreadyApplied = messages.any((message) => message.isSeatApplication && !message.applicationResolved && message.senderId == currentUser.id);
    if (alreadyApplied) return;
    selectedSeatIndex = null;
    messages.insert(0, ChatEntry(senderName: currentUser.name, senderId: currentUser.id, message: 'wants to join the mic', vipLevel: currentUser.vipLevel, sendingLevel: currentUser.sendingLevel, receivingLevel: currentUser.receivingLevel, isSeatApplication: true, seatIndex: index));
    onChanged();
  }

  void approveSeatApplication({required ChatEntry entry, required List<ChatEntry> messages, required List<SeatUser> allRoomUsers}) {
    if (!_currentUserIsAdminOrOwner) {
      onToast('Only the owner or room admins can approve seat requests');
      return;
    }
    final seatIndex = entry.seatIndex;
    if (seatIndex == null || seatIndex < 0 || seatIndex >= seats.length || entry.applicationResolved) return;
    final messageIndex = messages.indexOf(entry);
    if (seats[seatIndex].user != null || seats[seatIndex].locked) {
      if (messageIndex >= 0) messages[messageIndex] = entry.copyWith(message: '${entry.senderName} seat request expired', applicationApproved: true);
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
      LiveRoomAudioService.instance.takeSeat(seatIndex);
      LiveRoomAudioService.instance.setSelfMuted(micMuted);
    }
    if (messageIndex >= 0) messages[messageIndex] = entry.copyWith(message: '${entry.senderName} joined the mic', applicationApproved: true);
    onChanged();
  }

  void rejectSeatApplication({required ChatEntry entry, required List<ChatEntry> messages}) {
    if (!_currentUserIsAdminOrOwner) {
      onToast('Only the owner or room admins can reject seat requests');
      return;
    }
    if (!entry.isSeatApplication || entry.applicationResolved) return;
    final index = messages.indexOf(entry);
    if (index < 0) return;
    if (entry.senderId != null) _seatApplyCooldownUntil[entry.senderId!] = DateTime.now().add(const Duration(seconds: 20));
    messages[index] = entry.copyWith(message: '${entry.senderName} seat request rejected', applicationRejected: true);
    onChanged();
  }

  void switchSeat(int index) => occupySeat(index);

  void lockSeat(int index) {
    if (!_currentUserIsAdminOrOwner) {
      onToast('Only the owner or room admins can lock seats');
      return;
    }
    if (index < 0 || index >= seats.length) return;
    final wasCurrentUserSeat = seats[index].user?.id == currentUser.id;
    seats[index] = seats[index].copyWith(locked: true, clearUser: true);
    selectedSeatIndex = null;
    LiveRoomMediaSignalingService.instance.lockSeat(seatIndex: index);
    if (wasCurrentUserSeat) {
      LiveRoomMediaSignalingService.instance.leaveSeat();
      LiveRoomMediaSignalingService.instance.setMicEnabled(false);
      LiveRoomAudioService.instance.leaveSeat();
      LiveRoomAudioService.instance.setSelfMuted(true);
    }
    onChanged();
  }

  void unlockSeat(int index) {
    if (!_currentUserIsAdminOrOwner) {
      onToast('Only the owner or room admins can unlock seats');
      return;
    }
    if (index < 0 || index >= seats.length) return;
    seats[index] = seats[index].copyWith(locked: false);
    selectedSeatIndex = null;
    LiveRoomMediaSignalingService.instance.unlockSeat(seatIndex: index);
    onChanged();
  }

  void removeUserFromRoom(String userId) {
    final target = roomUsers.firstWhereOrNull((user) => user.id == userId);
    if (target == null || !_canRemoveTarget(target)) {
      onToast('You cannot remove this user');
      return;
    }
    var removed = false;
    for (var i = 0; i < seats.length; i++) {
      if (seats[i].user?.id == userId) {
        seats[i] = seats[i].copyWith(clearUser: true);
        removed = true;
      }
    }
    if (!removed) return;
    selectedSeatIndex = null;
    LiveRoomMediaSignalingService.instance.kickUser(targetUserId: userId);
    onChanged();
  }

  void kickUserFromRoom({required String userId, required String duration}) {
    final target = roomUsers.firstWhereOrNull((user) => user.id == userId);
    if (target == null || !_canRemoveTarget(target)) {
      onToast('You cannot kick this user');
      return;
    }
    var removed = false;
    for (var i = 0; i < seats.length; i++) {
      if (seats[i].user?.id == userId) {
        seats[i] = seats[i].copyWith(clearUser: true);
        removed = true;
      }
    }
    selectedSeatIndex = null;
    LiveRoomMediaSignalingService.instance.kickUser(targetUserId: userId, duration: duration);
    if (removed) onChanged();
  }

  void toggleMic() {
    final index = seats.indexWhere((seat) => seat.user?.id == currentUser.id);
    final localUser = index >= 0 ? seats[index].user : null;
    if (localUser?.adminMuted ?? false) {
      micMuted = true;
      if (index >= 0) seats[index] = seats[index].copyWith(user: localUser!.copyWith(selfMuted: true));
      LiveRoomMediaSignalingService.instance.setMicEnabled(false);
      LiveRoomAudioService.instance.setSelfMuted(true);
      onToast('You are muted by the room admin');
      onChanged();
      return;
    }

    micMuted = !micMuted;
    if (index >= 0) seats[index] = seats[index].copyWith(user: seats[index].user!.copyWith(selfMuted: micMuted));
    LiveRoomMediaSignalingService.instance.setMicEnabled(!micMuted && index >= 0);
    LiveRoomAudioService.instance.setSelfMuted(micMuted || index < 0);
    onChanged();
  }

  void toggleSelfMute(String userId) {
    final index = seats.indexWhere((seat) => seat.user?.id == userId);
    if (index < 0) return;
    final user = seats[index].user!;
    if (user.adminMuted && userId == currentUser.id) {
      seats[index] = seats[index].copyWith(user: user.copyWith(selfMuted: true));
      micMuted = true;
      LiveRoomMediaSignalingService.instance.setMicEnabled(false);
      LiveRoomAudioService.instance.setSelfMuted(true);
      onToast('You are muted by the room admin');
      onChanged();
      return;
    }
    final nextMuted = !user.selfMuted;
    seats[index] = seats[index].copyWith(user: user.copyWith(selfMuted: nextMuted));
    if (userId == currentUser.id) {
      micMuted = nextMuted;
      LiveRoomAudioService.instance.setSelfMuted(nextMuted);
    }
    onChanged();
  }

  void toggleAdminMute(String userId) {
    final index = seats.indexWhere((seat) => seat.user?.id == userId);
    if (index < 0) return;
    final user = seats[index].user!;
    if (!_canAdminMuteTarget(user)) {
      onToast('You cannot mute or unmute this user');
      return;
    }
    final nextMuted = !user.adminMuted;
    seats[index] = seats[index].copyWith(user: user.copyWith(adminMuted: nextMuted, selfMuted: nextMuted ? true : user.selfMuted));
    LiveRoomMediaSignalingService.instance.setAdminMute(targetUserId: userId, muted: nextMuted);
    onChanged();
  }

  void setUserAsAdmin(String userId) {
    if (!_currentUserIsOwner) {
      onToast('Only the room owner can set admins');
      return;
    }
    if (userId == currentUser.id) return;
    for (var i = 0; i < seats.length; i++) {
      final user = seats[i].user;
      if (user?.id == userId && !_isOwner(user!)) {
        seats[i] = seats[i].copyWith(user: user.copyWith(isRoomAdmin: true, roleLabel: 'Administrator'));
      }
    }
    onChanged();
  }

  void removeUserAsAdmin(String userId) {
    if (!_currentUserIsOwner) {
      onToast('Only the room owner can remove admins');
      return;
    }
    for (var i = 0; i < seats.length; i++) {
      final user = seats[i].user;
      if (user?.id == userId && !_isOwner(user!)) {
        seats[i] = seats[i].copyWith(user: user.copyWith(isRoomAdmin: false, roleLabel: 'Member'));
      }
    }
    onChanged();
  }

  void leaveAndLockSeat(int seatIndex) {
    if (!_currentUserIsAdminOrOwner) {
      onToast('Only the owner or room admins can leave-lock seats');
      return;
    }
    if (seatIndex < 0 || seatIndex >= seats.length) return;
    final seatedUser = seats[seatIndex].user;
    if (seatedUser != null && !_canRemoveTarget(seatedUser)) {
      onToast('You cannot leave-lock this user');
      return;
    }
    final isCurrentUserSeat = seatedUser?.id == currentUser.id;
    seats[seatIndex] = RoomSeat(index: seatIndex, locked: !isCurrentUserSeat);
    selectedSeatIndex = null;
    if (seatedUser != null) {
      LiveRoomMediaSignalingService.instance.leaveAndLockSeat(seatIndex: seatIndex, targetUserId: seatedUser.id);
    } else {
      LiveRoomMediaSignalingService.instance.lockSeat(seatIndex: seatIndex);
    }
    if (isCurrentUserSeat) {
      LiveRoomMediaSignalingService.instance.leaveSeat();
      LiveRoomAudioService.instance.leaveSeat();
      LiveRoomAudioService.instance.setSelfMuted(true);
    }
    onChanged();
  }

  void leaveSeatOnly(int seatIndex) {
    if (!_currentUserIsAdminOrOwner) {
      onToast('Only the owner or room admins can remove users from seats');
      return;
    }
    if (seatIndex < 0 || seatIndex >= seats.length) return;
    final seatedUser = seats[seatIndex].user;
    if (seatedUser == null) return;
    if (!_canRemoveTarget(seatedUser)) {
      onToast('You cannot remove this user from seat');
      return;
    }
    seats[seatIndex] = RoomSeat(index: seatIndex);
    selectedSeatIndex = null;
    LiveRoomMediaSignalingService.instance.forceLeaveSeat(seatIndex: seatIndex, targetUserId: seatedUser.id);
    onChanged();
  }
}

typedef VoidCallbackLike = void Function();
typedef ValueChangedLike<T> = void Function(T value);

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T item) test) {
    for (final item in this) {
      if (test(item)) return item;
    }
    return null;
  }
}
