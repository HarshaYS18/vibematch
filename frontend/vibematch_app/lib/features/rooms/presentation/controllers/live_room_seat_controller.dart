import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/live_room_media_signaling_service.dart';
import '../../data/live_room_presence_repository.dart';
import '../live_room_models.dart';

class LiveRoomSeatController {
  LiveRoomSeatController({required SeatUser currentUser, required this.onChanged, required this.onToast})
      : currentUser = LiveRoomMediaSignalingService.instance.effectiveCurrentUser(currentUser) {
    LiveRoomMediaSignalingService.instance.roomSnapshot.addListener(_applyLatestMediaSnapshot);
    LiveRoomPresenceRepository.activeParticipants.addListener(_applyLatestPresenceSnapshot);
  }

  SeatUser currentUser;
  final VoidCallbackLike onChanged;
  final ValueChangedLike<String> onToast;

  String layoutId = '5x2';
  int? selectedSeatIndex;
  bool micMuted = false;
  List<RoomSeat> seats = <RoomSeat>[];

  final Map<String, DateTime> _seatApplyCooldownUntil = <String, DateTime>{};
  final LiveRoomPresenceRepository _presenceRepository = LiveRoomPresenceRepository();

  List<SeatUser> get roomUsers => seats.where((seat) => seat.user != null).map((seat) => seat.user!).toList();

  bool get _currentUserIsOwner => _roomPower(currentUser) >= 100;
  bool get _currentUserIsAdminOrOwner => _roomPower(currentUser) >= 90;

  bool canModerateTarget(SeatUser target) => _canModerateTarget(target);
  bool canSetOrRemoveAdminFor(SeatUser target) => _currentUserIsOwner && target.id != currentUser.id && _roomPower(target) < 100;
  int roomPowerFor(SeatUser user) => _roomPower(user);

  void dispose() {
    LiveRoomMediaSignalingService.instance.roomSnapshot.removeListener(_applyLatestMediaSnapshot);
    LiveRoomPresenceRepository.activeParticipants.removeListener(_applyLatestPresenceSnapshot);
  }

  void initialize(String initialLayoutId) {
    layoutId = initialLayoutId;
    seats = buildSeatsForLayout(layoutId);
    _refreshCurrentUserFromPresence();
    _applyLatestMediaSnapshot();
    LiveRoomMediaSignalingService.instance.joinRoom(currentUser: currentUser);
    Future<void>.microtask(_applyLatestMediaSnapshot);
  }

  List<RoomSeat> buildSeatsForLayout(String targetLayoutId) {
    final spec = SeatLayoutSpec.parse(targetLayoutId);
    return List<RoomSeat>.generate(spec.totalSeats, (index) => RoomSeat(index: index));
  }

  void _applyLatestPresenceSnapshot() {
    final changed = _refreshCurrentUserFromPresence();
    if (changed) {
      _applyLatestMediaSnapshot();
      onChanged();
    }
  }

  bool _refreshCurrentUserFromPresence() {
    final liveUser = LiveRoomPresenceRepository.currentParticipantsForRoom(LiveRoomMediaSignalingService.instance.roomId).firstWhereOrNull((user) => user.id == currentUser.id);
    if (liveUser == null) return false;
    final nextUser = _mergePresenceIntoCurrentUser(liveUser);
    final changed = nextUser.isRoomAdmin != currentUser.isRoomAdmin || nextUser.isHost != currentUser.isHost || nextUser.roleLabel != currentUser.roleLabel;
    if (!changed) return false;
    currentUser = nextUser;
    LiveRoomMediaSignalingService.instance.seedActiveRoomSeatUser(nextUser);
    return true;
  }

  SeatUser _mergePresenceIntoCurrentUser(SeatUser liveUser) {
    return currentUser.copyWith(
      isHost: liveUser.isHost,
      isRoomAdmin: liveUser.isRoomAdmin,
      roleLabel: liveUser.roleLabel,
      vipLevel: liveUser.vipLevel,
      svipLevel: liveUser.svipLevel,
    );
  }

  void _applyLatestMediaSnapshot() {
    _refreshCurrentUserFromPresence();
    final snapshot = LiveRoomMediaSignalingService.instance.roomSnapshot.value;
    if (snapshot == null || seats.isEmpty) return;

    final previousUsers = <String, SeatUser>{for (final user in roomUsers) user.id: user, currentUser.id: currentUser};
    for (final user in LiveRoomPresenceRepository.currentParticipantsForRoom(LiveRoomMediaSignalingService.instance.roomId)) {
      previousUsers[user.id] = user;
    }

    final nextSeats = List<RoomSeat>.generate(seats.length, (index) => RoomSeat(index: index, locked: snapshot.lockedSeatIndexes.contains(index)));
    final usedSeatIndexes = <int>{};

    for (final peer in snapshot.peers) {
      final seatIndex = peer.seatIndex;
      if (seatIndex == null || seatIndex < 0 || seatIndex >= nextSeats.length) continue;
      if (usedSeatIndexes.contains(seatIndex)) continue;

      final baseUser = peer.userId == currentUser.id ? currentUser : previousUsers[peer.userId];
      final seatUser = _seatUserFromPeer(peer: peer, baseUser: baseUser);
      nextSeats[seatIndex] = nextSeats[seatIndex].copyWith(user: seatUser, locked: snapshot.lockedSeatIndexes.contains(seatIndex));
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

  SeatUser _seatUserFromPeer({required LiveMediaPeerSnapshot peer, SeatUser? baseUser}) {
    final displayName = peer.displayName.trim().isNotEmpty ? peer.displayName.trim() : (baseUser?.name ?? _fallbackDisplayNameForUserId(peer.userId));
    final isFounder = _isFounderId(peer.userId);
    return SeatUser(
      id: peer.userId,
      name: displayName,
      roleLabel: baseUser?.roleLabel ?? (isFounder ? 'Channel Host' : 'Member'),
      familyName: baseUser?.familyName ?? '',
      familyLevel: baseUser?.familyLevel ?? 'bronze',
      relationshipText: baseUser?.relationshipText ?? '',
      vipLevel: baseUser?.vipLevel ?? (isFounder ? 32 : 0),
      svipLevel: baseUser?.svipLevel ?? (isFounder ? 3 : 0),
      sendingLevel: baseUser?.sendingLevel ?? 1,
      receivingLevel: baseUser?.receivingLevel ?? 1,
      sentExp: baseUser?.sentExp ?? 0,
      receivedExp: baseUser?.receivedExp ?? 0,
      medals: baseUser?.medals ?? const [],
      avatarColors: baseUser?.avatarColors ?? const [Color(0xFF12C7B7), Color(0xFF6D5DF6)],
      age: baseUser?.age,
      locationLabel: baseUser?.locationLabel,
      locationVisible: baseUser?.locationVisible ?? true,
      gender: baseUser?.gender ?? RoomUserGender.undisclosed,
      isCurrentUser: peer.userId == currentUser.id,
      isHost: baseUser?.isHost ?? isFounder,
      isRoomAdmin: baseUser?.isRoomAdmin ?? isFounder,
      selfMuted: !peer.micEnabled,
      adminMuted: peer.adminMuted,
    );
  }

  String _fallbackDisplayNameForUserId(String userId) {
    if (_isFounderId(userId)) return 'Founder Owner';
    final publicId = userId.startsWith('user_') ? userId.substring(5) : userId;
    return publicId.trim().isEmpty ? 'Vibe User' : 'User $publicId';
  }

  bool _isFounderId(String userId) => userId == 'user_6922022' || userId == 'founder_owner';

  int _roomPower(SeatUser user) {
    final role = user.roleLabel.toLowerCase();
    final isOwner = user.isHost || _isFounderId(user.id) || role.contains('owner') || role.contains('channel host') || role == 'host';
    if (isOwner) return 100;
    final isAdmin = user.isRoomAdmin || role == 'admin' || role.contains('admin') || role.contains('administrator');
    if (isAdmin) return 90;
    return 0;
  }

  bool _canModerateTarget(SeatUser target) {
    final viewerPower = _roomPower(currentUser);
    final targetPower = _roomPower(target);
    if (target.id == currentUser.id) return false;
    if (targetPower >= 100) return false;
    if (viewerPower >= 100) return targetPower < 100;
    if (viewerPower >= 90) return targetPower < 90;
    return false;
  }

  bool _canAdminMuteTarget(SeatUser target) => _canModerateTarget(target);
  bool _canRemoveTarget(SeatUser target) => _canModerateTarget(target);

  SeatUser? _findRoomParticipant(String userId) {
    final seated = roomUsers.firstWhereOrNull((user) => user.id == userId);
    if (seated != null) return seated;
    return LiveRoomPresenceRepository.currentParticipantsForRoom(LiveRoomMediaSignalingService.instance.roomId).firstWhereOrNull((user) => user.id == userId);
  }

  int? _publicUserIdFromRoomUserId(String userId) {
    final clean = userId.startsWith('user_') ? userId.substring(5) : userId;
    return int.tryParse(clean);
  }

  void _publishParticipantRole(SeatUser user) {
    LiveRoomPresenceRepository.publishParticipant(user);
    if (user.id == currentUser.id) {
      currentUser = _mergePresenceIntoCurrentUser(user);
      LiveRoomMediaSignalingService.instance.seedActiveRoomSeatUser(currentUser);
    }
    for (var i = 0; i < seats.length; i++) {
      final seated = seats[i].user;
      if (seated?.id == user.id) seats[i] = seats[i].copyWith(user: user.copyWith(selfMuted: seated!.selfMuted, adminMuted: seated.adminMuted));
    }
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

  void toggleSelectedSeat(int index) { selectedSeatIndex = selectedSeatIndex == index ? null : index; onChanged(); }
  void clearSelectedSeat() { selectedSeatIndex = null; onChanged(); }

  void occupySeat(int index) {
    if (index < 0 || index >= seats.length) return;
    if (seats[index].locked) { onToast('This seat is locked'); return; }
    selectedSeatIndex = null;
    LiveRoomMediaSignalingService.instance.takeSeat(index);
    LiveRoomMediaSignalingService.instance.setMicEnabled(!micMuted);
    onChanged();
  }

  bool inviteUserToSeat({required int seatIndex, required SeatUser invitedUser}) {
    if (!_currentUserIsAdminOrOwner) { onToast('Only the owner or room admins can invite users to seats'); return false; }
    if (seatIndex < 0 || seatIndex >= seats.length || seats[seatIndex].locked || seats[seatIndex].user != null) return false;
    if (invitedUser.id == currentUser.id) { onToast('You cannot invite yourself to a seat'); return false; }
    selectedSeatIndex = null;
    LiveRoomMediaSignalingService.instance.sendSeatInvite(seatIndex: seatIndex, targetUserId: invitedUser.id);
    onChanged();
    return true;
  }

  void applyForSeat({required int index, required List<ChatEntry> messages}) {
    if (_currentUserIsAdminOrOwner) { occupySeat(index); return; }
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
    if (!_currentUserIsAdminOrOwner) { onToast('Only the owner or room admins can approve seat requests'); return; }
    final seatIndex = entry.seatIndex;
    if (seatIndex == null || seatIndex < 0 || seatIndex >= seats.length || entry.applicationResolved) return;
    final messageIndex = messages.indexOf(entry);
    if (seats[seatIndex].user != null || seats[seatIndex].locked) {
      if (messageIndex >= 0) messages[messageIndex] = entry.copyWith(message: '${entry.senderName} seat request expired', applicationApproved: true);
      onChanged();
      return;
    }
    final applicant = allRoomUsers.firstWhere((user) => user.id == entry.senderId, orElse: () => currentUser);
    if (applicant.id == currentUser.id) LiveRoomMediaSignalingService.instance.takeSeat(seatIndex);
    if (messageIndex >= 0) messages[messageIndex] = entry.copyWith(message: '${entry.senderName} joined the mic', applicationApproved: true);
    onChanged();
  }

  void rejectSeatApplication({required ChatEntry entry, required List<ChatEntry> messages}) {
    if (!_currentUserIsAdminOrOwner) { onToast('Only the owner or room admins can reject seat requests'); return; }
    if (!entry.isSeatApplication || entry.applicationResolved) return;
    final index = messages.indexOf(entry);
    if (index < 0) return;
    if (entry.senderId != null) _seatApplyCooldownUntil[entry.senderId!] = DateTime.now().add(const Duration(seconds: 20));
    messages[index] = entry.copyWith(message: '${entry.senderName} seat request rejected', applicationRejected: true);
    onChanged();
  }

  void switchSeat(int index) => occupySeat(index);

  void lockSeat(int index) {
    if (!_currentUserIsAdminOrOwner) { onToast('Only the owner or room admins can lock seats'); return; }
    if (index < 0 || index >= seats.length) return;
    final wasCurrentUserSeat = seats[index].user?.id == currentUser.id;
    seats[index] = seats[index].copyWith(locked: true, clearUser: true);
    selectedSeatIndex = null;
    LiveRoomMediaSignalingService.instance.lockSeat(seatIndex: index);
    if (wasCurrentUserSeat) LiveRoomMediaSignalingService.instance.leaveSeat();
    onChanged();
  }

  void unlockSeat(int index) {
    if (!_currentUserIsAdminOrOwner) { onToast('Only the owner or room admins can unlock seats'); return; }
    if (index < 0 || index >= seats.length) return;
    seats[index] = seats[index].copyWith(locked: false);
    selectedSeatIndex = null;
    LiveRoomMediaSignalingService.instance.unlockSeat(seatIndex: index);
    onChanged();
  }

  void removeUserFromRoom(String userId) {
    final target = _findRoomParticipant(userId);
    if (target == null || !_canRemoveTarget(target)) { onToast('You cannot remove this user'); return; }
    selectedSeatIndex = null;
    LiveRoomMediaSignalingService.instance.kickUser(targetUserId: userId);
  }

  void kickUserFromRoom({required String userId, required String duration}) {
    final target = _findRoomParticipant(userId);
    if (target == null || !_canRemoveTarget(target)) { onToast('You cannot kick this user'); return; }
    selectedSeatIndex = null;
    LiveRoomMediaSignalingService.instance.kickUser(targetUserId: userId, duration: duration);
  }

  void toggleMic() {
    final index = seats.indexWhere((seat) => seat.user?.id == currentUser.id);
    final localUser = index >= 0 ? seats[index].user : null;
    if (localUser?.adminMuted ?? false) { LiveRoomMediaSignalingService.instance.setMicEnabled(false); onToast('You are muted by the room admin'); return; }
    final nextMuted = !(localUser?.selfMuted ?? micMuted);
    LiveRoomMediaSignalingService.instance.setMicEnabled(!nextMuted && index >= 0);
  }

  void toggleSelfMute(String userId) {
    final index = seats.indexWhere((seat) => seat.user?.id == userId);
    if (index < 0) return;
    final user = seats[index].user!;
    if (user.id != currentUser.id) { onToast('You can only mute your own mic'); return; }
    if (user.adminMuted) { LiveRoomMediaSignalingService.instance.setMicEnabled(false); onToast('You are muted by the room admin'); return; }
    final nextMuted = !user.selfMuted;
    LiveRoomMediaSignalingService.instance.setMicEnabled(!nextMuted);
  }

  void toggleAdminMute(String userId) {
    final index = seats.indexWhere((seat) => seat.user?.id == userId);
    if (index < 0) return;
    final user = seats[index].user!;
    if (!_canAdminMuteTarget(user)) { onToast('You cannot mute or unmute this user'); return; }
    final nextMuted = !user.adminMuted;
    LiveRoomMediaSignalingService.instance.setAdminMute(targetUserId: userId, muted: nextMuted);
  }

  void setUserAsAdmin(String userId) {
    final target = _findRoomParticipant(userId);
    if (!_currentUserIsOwner || target == null || !canSetOrRemoveAdminFor(target)) { onToast('Only the room owner can set admins'); return; }
    final promoted = target.copyWith(isRoomAdmin: true, roleLabel: 'Admin');
    _publishParticipantRole(promoted);
    onChanged();
    final publicUserId = _publicUserIdFromRoomUserId(userId);
    final roomId = LiveRoomMediaSignalingService.instance.roomId;
    if (publicUserId == null || roomId == null || roomId.trim().isEmpty) {
      onToast('${target.name} is now Admin');
      return;
    }
    unawaited(_presenceRepository.addRoomAdmin(roomId: roomId, publicUserId: publicUserId).then((serverUser) {
      _publishParticipantRole(serverUser.copyWith(isRoomAdmin: true, roleLabel: 'Admin'));
      onChanged();
    }).catchError((Object error) {
      onToast(error.toString().replaceFirst('Exception: ', ''));
    }));
    onToast('${target.name} is now Admin');
  }

  void removeUserAsAdmin(String userId) {
    final target = _findRoomParticipant(userId);
    if (!_currentUserIsOwner || target == null || !canSetOrRemoveAdminFor(target)) { onToast('Only the room owner can remove admins'); return; }
    final demoted = target.copyWith(isRoomAdmin: false, roleLabel: 'Member');
    _publishParticipantRole(demoted);
    onChanged();
    final publicUserId = _publicUserIdFromRoomUserId(userId);
    final roomId = LiveRoomMediaSignalingService.instance.roomId;
    if (publicUserId == null || roomId == null || roomId.trim().isEmpty) {
      onToast('${target.name} is no longer Admin');
      return;
    }
    unawaited(_presenceRepository.removeRoomAdmin(roomId: roomId, publicUserId: publicUserId).then((serverUser) {
      _publishParticipantRole(serverUser.copyWith(isRoomAdmin: false, roleLabel: 'Member'));
      onChanged();
    }).catchError((Object error) {
      onToast(error.toString().replaceFirst('Exception: ', ''));
    }));
    onToast('${target.name} is no longer Admin');
  }

  void leaveAndLockSeat(int seatIndex) {
    if (!_currentUserIsAdminOrOwner) { onToast('Only the owner or room admins can leave-lock seats'); return; }
    if (seatIndex < 0 || seatIndex >= seats.length) return;
    final seatedUser = seats[seatIndex].user;
    if (seatedUser != null && seatedUser.id == currentUser.id) {
      LiveRoomMediaSignalingService.instance.leaveSeat();
      return;
    }
    if (seatedUser != null && !_canRemoveTarget(seatedUser)) { onToast('You cannot leave-lock this user'); return; }
    if (seatedUser != null) {
      LiveRoomMediaSignalingService.instance.leaveAndLockSeat(seatIndex: seatIndex, targetUserId: seatedUser.id);
    } else {
      LiveRoomMediaSignalingService.instance.lockSeat(seatIndex: seatIndex);
    }
  }

  void leaveSeatOnly(int seatIndex) {
    if (seatIndex < 0 || seatIndex >= seats.length) return;
    final seatedUser = seats[seatIndex].user;
    if (seatedUser == null) return;
    if (seatedUser.id == currentUser.id) { LiveRoomMediaSignalingService.instance.leaveSeat(); return; }
    if (!_currentUserIsAdminOrOwner) { onToast('Only the owner or room admins can remove users from seats'); return; }
    if (!_canRemoveTarget(seatedUser)) { onToast('You cannot remove this user from seat'); return; }
    LiveRoomMediaSignalingService.instance.forceLeaveSeat(seatIndex: seatIndex, targetUserId: seatedUser.id);
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
