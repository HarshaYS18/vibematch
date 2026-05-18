import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/live_room_media_signaling_service.dart';
import '../../data/live_room_presence_repository.dart';
import '../live_room_models.dart';
import '../live_room_restore_state.dart';

class LiveRoomSeatController {
  LiveRoomSeatController({
    required SeatUser currentUser,
    required this.onChanged,
    required this.onToast,
  }) : currentUser = LiveRoomMediaSignalingService.instance
           .effectiveCurrentUser(currentUser) {
    LiveRoomMediaSignalingService.instance.roomSnapshot.addListener(
      _applyLatestMediaSnapshot,
    );
    LiveRoomPresenceRepository.activeParticipants.addListener(
      _applyLatestPresenceSnapshot,
    );
  }

  static const Duration seatApplicationExpiry = Duration(seconds: 20);
  static const Duration seatApplicationCooldown = Duration(seconds: 30);

  SeatUser currentUser;
  final VoidCallbackLike onChanged;
  final ValueChangedLike<String> onToast;

  String layoutId = '5x2';
  int? selectedSeatIndex;
  bool micMuted = false;
  List<RoomSeat> seats = <RoomSeat>[];

  final Map<String, DateTime> _seatApplyCooldownUntil = <String, DateTime>{};
  final LiveRoomPresenceRepository _presenceRepository =
      LiveRoomPresenceRepository();

  List<SeatUser> get roomUsers => seats
      .where((seat) => seat.user != null)
      .map((seat) => seat.user!)
      .toList();
  bool get currentUserIsSeated =>
      seats.any((seat) => _sameRoomUserId(seat.user?.id, currentUser.id));

  bool get _currentUserIsOwner => _roomPower(currentUser) >= 100;
  bool get _currentUserIsAdminOrOwner => _roomPower(currentUser) >= 90;

  bool canModerateTarget(SeatUser target) => _canModerateTarget(target);
  bool canSetOrRemoveAdminFor(SeatUser target) =>
      _currentUserIsOwner &&
      !_sameRoomUserId(target.id, currentUser.id) &&
      _roomPower(target) < 100;
  int roomPowerFor(SeatUser user) => _roomPower(user);

  void dispose() {
    LiveRoomMediaSignalingService.instance.roomSnapshot.removeListener(
      _applyLatestMediaSnapshot,
    );
    LiveRoomPresenceRepository.activeParticipants.removeListener(
      _applyLatestPresenceSnapshot,
    );
  }

  void initialize(
    String initialLayoutId, {
    LiveRoomSeatRestoreState? restoreState,
  }) {
    layoutId = initialLayoutId;
    seats = restoreState?.seats.isNotEmpty == true
        ? List<RoomSeat>.from(restoreState!.seats)
        : buildSeatsForLayout(layoutId);
    selectedSeatIndex = restoreState?.selectedSeatIndex;
    micMuted = restoreState?.micMuted ?? micMuted;
    _refreshCurrentUserFromPresence();
    _applyLatestMediaSnapshot();
    LiveRoomMediaSignalingService.instance.joinRoom(currentUser: currentUser);
    Future<void>.microtask(_applyLatestMediaSnapshot);
  }

  LiveRoomSeatRestoreState snapshotForRestore() {
    return LiveRoomSeatRestoreState(
      layoutId: layoutId,
      seats: List<RoomSeat>.from(seats),
      selectedSeatIndex: selectedSeatIndex,
      micMuted: micMuted,
    );
  }

  List<RoomSeat> buildSeatsForLayout(String targetLayoutId) {
    final spec = SeatLayoutSpec.parse(targetLayoutId);
    return List<RoomSeat>.generate(
      spec.totalSeats,
      (index) => RoomSeat(index: index),
    );
  }

  void _applyLatestPresenceSnapshot() {
    final changed = _refreshCurrentUserFromPresence();
    if (changed) {
      _applyLatestMediaSnapshot();
      onChanged();
    }
  }

  bool _refreshCurrentUserFromPresence() {
    final liveUser = LiveRoomPresenceRepository.currentParticipantsForRoom(
      LiveRoomMediaSignalingService.instance.roomId,
    ).firstWhereOrNull((user) => _sameRoomUserId(user.id, currentUser.id));
    if (liveUser == null) return false;
    final nextUser = _mergePresenceIntoCurrentUser(liveUser);
    final changed =
        nextUser.isRoomAdmin != currentUser.isRoomAdmin ||
        nextUser.isHost != currentUser.isHost ||
        nextUser.name != currentUser.name ||
        nextUser.roleLabel != currentUser.roleLabel ||
        nextUser.avatarUrl != currentUser.avatarUrl ||
        nextUser.vipLevel != currentUser.vipLevel ||
        nextUser.svipLevel != currentUser.svipLevel ||
        nextUser.sendingLevel != currentUser.sendingLevel ||
        nextUser.receivingLevel != currentUser.receivingLevel ||
        nextUser.sentExp != currentUser.sentExp ||
        nextUser.receivedExp != currentUser.receivedExp;
    if (!changed) return false;
    currentUser = nextUser;
    LiveRoomMediaSignalingService.instance.seedActiveRoomSeatUser(nextUser);
    return true;
  }

  SeatUser _mergePresenceIntoCurrentUser(SeatUser liveUser) {
    return currentUser.copyWith(
      isHost: liveUser.isHost,
      isRoomAdmin: liveUser.isRoomAdmin,
      name: liveUser.name,
      roleLabel: liveUser.roleLabel,
      vipLevel: liveUser.vipLevel,
      svipLevel: liveUser.svipLevel,
      sendingLevel: liveUser.sendingLevel,
      receivingLevel: liveUser.receivingLevel,
      sentExp: liveUser.sentExp,
      receivedExp: liveUser.receivedExp,
      avatarUrl: liveUser.avatarUrl,
    );
  }

  void _applyLatestMediaSnapshot() {
    _refreshCurrentUserFromPresence();
    final snapshot = LiveRoomMediaSignalingService.instance.roomSnapshot.value;
    if (snapshot == null || seats.isEmpty) return;

    final previousUsers = <String, SeatUser>{};
    void rememberUser(SeatUser user) {
      for (final alias in _identityAliases(user.id)) {
        previousUsers[alias] = user;
      }
    }

    for (final user in roomUsers) {
      rememberUser(user);
    }
    rememberUser(currentUser);
    for (final user in LiveRoomPresenceRepository.currentParticipantsForRoom(
      LiveRoomMediaSignalingService.instance.roomId,
    )) {
      rememberUser(user);
    }

    final nextSeats = List<RoomSeat>.generate(
      seats.length,
      (index) => RoomSeat(
        index: index,
        locked: snapshot.lockedSeatIndexes.contains(index),
      ),
    );
    final usedSeatIndexes = <int>{};

    for (final peer in snapshot.peers) {
      final seatIndex = peer.seatIndex;
      if (seatIndex == null || seatIndex < 0 || seatIndex >= nextSeats.length) {
        continue;
      }
      if (usedSeatIndexes.contains(seatIndex)) continue;
      final baseUser = _peerMatchesUser(peer, currentUser)
          ? currentUser
          : _findPreviousUserForPeer(peer, previousUsers);
      final seatUser = _seatUserFromPeer(peer: peer, baseUser: baseUser);
      nextSeats[seatIndex] = nextSeats[seatIndex].copyWith(
        user: seatUser,
        locked: snapshot.lockedSeatIndexes.contains(seatIndex),
      );
      usedSeatIndexes.add(seatIndex);
    }

    seats = nextSeats;
    final localSeat = seats.firstWhereOrNull(
      (seat) => _sameRoomUserId(seat.user?.id, currentUser.id),
    );
    micMuted = localSeat?.user?.selfMuted ?? micMuted;
    if (selectedSeatIndex != null &&
        selectedSeatIndex! >= 0 &&
        selectedSeatIndex! < seats.length) {
      final selectedSeat = seats[selectedSeatIndex!];
      if (selectedSeat.user != null) selectedSeatIndex = null;
    }
    onChanged();
  }

  SeatUser? _findPreviousUserForPeer(
    LiveMediaPeerSnapshot peer,
    Map<String, SeatUser> previousUsers,
  ) {
    for (final alias in _peerAliases(peer)) {
      final user = previousUsers[alias];
      if (user != null) return user;
    }
    return null;
  }

  SeatUser _seatUserFromPeer({
    required LiveMediaPeerSnapshot peer,
    SeatUser? baseUser,
  }) {
    final displayName = peer.displayName.trim().isNotEmpty
        ? peer.displayName.trim()
        : (baseUser?.name ?? _fallbackDisplayNameForUserId(peer.userId));
    final isFounder = _isFounderId(peer.userId) || _isFounderId(peer.peerId);
    final resolvedId = baseUser?.id ?? _preferredRoomUserIdFromPeer(peer);
    return SeatUser(
      id: resolvedId,
      name: displayName,
      roleLabel: peer.isHost
          ? 'Channel Host'
          : peer.isRoomAdmin
          ? 'Admin'
          : (peer.roleLabel.trim().isNotEmpty
                ? peer.roleLabel
                : baseUser?.roleLabel ??
                      (isFounder ? 'Channel Host' : 'Member')),
      familyName: baseUser?.familyName ?? '',
      familyLevel: baseUser?.familyLevel ?? 'bronze',
      relationshipText: baseUser?.relationshipText ?? '',
      vipLevel: peer.vipLevel > 0 ? peer.vipLevel : baseUser?.vipLevel ?? 0,
      svipLevel: peer.svipLevel > 0 ? peer.svipLevel : baseUser?.svipLevel ?? 0,
      sendingLevel: peer.sendingLevel > 0
          ? peer.sendingLevel
          : baseUser?.sendingLevel ?? 0,
      receivingLevel: peer.receivingLevel > 0
          ? peer.receivingLevel
          : baseUser?.receivingLevel ?? 0,
      sentExp: baseUser?.sentExp ?? 0,
      receivedExp: baseUser?.receivedExp ?? 0,
      medals: baseUser?.medals ?? const [],
      avatarColors:
          baseUser?.avatarColors ??
          const [Color(0xFF12C7B7), Color(0xFF6D5DF6)],
      avatarUrl: peer.avatarUrl ?? baseUser?.avatarUrl,
      age: baseUser?.age,
      locationLabel: baseUser?.locationLabel,
      locationVisible: baseUser?.locationVisible ?? true,
      gender: baseUser?.gender ?? RoomUserGender.undisclosed,
      isCurrentUser: _peerMatchesUser(peer, currentUser),
      isHost: peer.isHost || (baseUser?.isHost ?? isFounder),
      isRoomAdmin:
          peer.isRoomAdmin ||
          peer.isHost ||
          (baseUser?.isRoomAdmin ?? isFounder),
      selfMuted: !peer.micEnabled,
      adminMuted: peer.adminMuted,
    );
  }

  String _preferredRoomUserIdFromPeer(LiveMediaPeerSnapshot peer) {
    final publicId =
        _publicUserIdFromAny(peer.peerId) ?? _publicUserIdFromAny(peer.userId);
    if (publicId != null) return 'user_$publicId';
    return peer.userId;
  }

  String _fallbackDisplayNameForUserId(String userId) {
    if (_isFounderId(userId)) return 'Founder Owner';
    final publicId = userId.startsWith('user_') ? userId.substring(5) : userId;
    return publicId.trim().isEmpty ? 'Vibe User' : 'User $publicId';
  }

  bool _isFounderId(String userId) {
    final aliases = _identityAliases(userId);
    return aliases.contains('6922022') ||
        aliases.contains('user_6922022') ||
        aliases.contains('founder_owner');
  }

  int _roomPower(SeatUser user) {
    final role = user.roleLabel.toLowerCase();
    final isOwner =
        user.isHost ||
        _isFounderId(user.id) ||
        role.contains('owner') ||
        role.contains('channel host') ||
        role == 'host';
    if (isOwner) return 100;
    final isAdmin =
        user.isRoomAdmin ||
        role == 'admin' ||
        role.contains('admin') ||
        role.contains('administrator');
    if (isAdmin) return 90;
    return 0;
  }

  bool _canModerateTarget(SeatUser target) {
    final viewerPower = _roomPower(currentUser);
    final targetPower = _roomPower(target);
    if (_sameRoomUserId(target.id, currentUser.id)) return false;
    if (targetPower >= 100) return false;
    if (viewerPower >= 100) return targetPower < 100;
    if (viewerPower >= 90) return targetPower < 90;
    return false;
  }

  bool _canAdminMuteTarget(SeatUser target) => _canModerateTarget(target);
  bool _canRemoveTarget(SeatUser target) => _canModerateTarget(target);

  SeatUser? _findRoomParticipant(String userId) {
    final seated = roomUsers.firstWhereOrNull(
      (user) => _sameRoomUserId(user.id, userId),
    );
    if (seated != null) return seated;

    final presence = LiveRoomPresenceRepository.currentParticipantsForRoom(
      LiveRoomMediaSignalingService.instance.roomId,
    ).firstWhereOrNull((user) => _sameRoomUserId(user.id, userId));
    if (presence != null) return presence;

    final snapshot = LiveRoomMediaSignalingService.instance.roomSnapshot.value;
    if (snapshot == null) return null;

    final peer = snapshot.peers.firstWhereOrNull(
      (item) =>
          _sameRoomUserId(item.userId, userId) ||
          _sameRoomUserId(item.peerId, userId),
    );
    if (peer == null) return null;

    return _seatUserFromPeer(peer: peer);
  }

  int? _publicUserIdFromRoomUserId(String userId) =>
      _publicUserIdFromAny(userId);

  void _publishParticipantRole(SeatUser user) {
    LiveRoomPresenceRepository.publishParticipant(user);
    if (_sameRoomUserId(user.id, currentUser.id)) {
      currentUser = _mergePresenceIntoCurrentUser(user);
      LiveRoomMediaSignalingService.instance.seedActiveRoomSeatUser(
        currentUser,
      );
    }
    for (var i = 0; i < seats.length; i++) {
      final seated = seats[i].user;
      if (_sameRoomUserId(seated?.id, user.id)) {
        seats[i] = seats[i].copyWith(
          user: user.copyWith(
            selfMuted: seated!.selfMuted,
            adminMuted: seated.adminMuted,
          ),
        );
      }
    }
  }

  void changeLayout(String nextLayoutId) {
    final existingUsers = roomUsers;
    layoutId = nextLayoutId;
    seats = List<RoomSeat>.generate(
      SeatLayoutSpec.parse(nextLayoutId).totalSeats,
      (index) => RoomSeat(index: index),
    );
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
    if (seats[index].locked) {
      onToast('This seat is locked');
      return;
    }
    selectedSeatIndex = null;
    LiveRoomMediaSignalingService.instance.takeSeat(index);
    LiveRoomMediaSignalingService.instance.setMicEnabled(!micMuted);
    onChanged();
  }

  bool inviteUserToSeat({
    required int seatIndex,
    required SeatUser invitedUser,
  }) {
    if (!_currentUserIsAdminOrOwner) {
      onToast('Only the owner or room admins can invite users to seats');
      return false;
    }
    if (seatIndex < 0 ||
        seatIndex >= seats.length ||
        seats[seatIndex].locked ||
        seats[seatIndex].user != null) {
      return false;
    }
    if (_sameRoomUserId(invitedUser.id, currentUser.id)) {
      onToast('You cannot invite yourself to a seat');
      return false;
    }
    selectedSeatIndex = null;
    LiveRoomMediaSignalingService.instance.sendSeatInvite(
      seatIndex: seatIndex,
      targetUserId: invitedUser.id,
    );
    onChanged();
    return true;
  }

  void expireSeatApplications(List<ChatEntry> messages) {
    var changed = false;
    for (var i = 0; i < messages.length; i++) {
      final entry = messages[i];
      if (!entry.isSeatApplication ||
          entry.applicationApproved ||
          entry.applicationRejected ||
          entry.applicationExpired) {
        continue;
      }
      final expiresAt = entry.applicationExpiresAt;
      if (expiresAt == null || DateTime.now().isBefore(expiresAt)) continue;
      messages[i] = entry.copyWith(
        message:
            '${entry.senderName} seat ${entry.seatIndex == null ? '' : entry.seatIndex! + 1} request expired',
        applicationExpired: true,
      );
      changed = true;
    }
    if (changed) onChanged();
  }

  void applyForSeat({required int index, required List<ChatEntry> messages}) {
    expireSeatApplications(messages);
    if (_currentUserIsAdminOrOwner) {
      occupySeat(index);
      return;
    }
    if (index < 0 || index >= seats.length) return;
    final seat = seats[index];
    if (seat.locked) {
      onToast('This seat is locked');
      return;
    }
    if (seat.user != null) {
      onToast('Seat ${index + 1} is already occupied');
      return;
    }

    final now = DateTime.now();
    final cooldownUntil = _seatApplyCooldownUntil[currentUser.id];
    if (cooldownUntil != null && cooldownUntil.isAfter(now)) {
      final remaining = cooldownUntil
          .difference(now)
          .inSeconds
          .clamp(1, seatApplicationCooldown.inSeconds);
      onToast('Please apply again after $remaining seconds');
      return;
    }

    final alreadyApplied = messages.any(
      (message) =>
          message.isSeatApplication &&
          !message.applicationResolved &&
          _sameRoomUserId(message.senderId, currentUser.id),
    );
    if (alreadyApplied) {
      onToast('You already have a pending seat request');
      return;
    }

    selectedSeatIndex = null;
    _seatApplyCooldownUntil[currentUser.id] = now.add(seatApplicationCooldown);
    LiveRoomMediaSignalingService.instance.sendSeatApplicationRequest(
      seatIndex: index,
    );
    onToast('Seat request sent');
    onChanged();
  }

  void approveSeatApplication({
    required ChatEntry entry,
    required List<ChatEntry> messages,
    required List<SeatUser> allRoomUsers,
  }) {
    if (!_currentUserIsAdminOrOwner) {
      onToast('Only the owner or room admins can approve seat requests');
      return;
    }

    final messageIndex = messages.indexOf(entry);
    if (messageIndex < 0) {
      return;
    }

    final latestEntry = messages[messageIndex];
    if (!latestEntry.isSeatApplication) {
      return;
    }

    if (latestEntry.applicationResolved) {
      onToast('This application has already been processed');
      return;
    }

    final seatIndex = latestEntry.seatIndex;
    if (seatIndex == null || seatIndex < 0 || seatIndex >= seats.length) {
      messages[messageIndex] = latestEntry.copyWith(
        message: '${latestEntry.senderName} seat request expired',
        applicationExpired: true,
      );
      onChanged();
      return;
    }

    final requestedSeat = seats[seatIndex];

    if (requestedSeat.locked) {
      messages[messageIndex] = latestEntry.copyWith(
        message:
            '${latestEntry.senderName} seat ${seatIndex + 1} request expired',
        applicationExpired: true,
      );
      onToast('Seat ${seatIndex + 1} is locked');
      onChanged();
      return;
    }

    if (requestedSeat.user != null) {
      messages[messageIndex] = latestEntry.copyWith(
        message:
            '${latestEntry.senderName} seat ${seatIndex + 1} request expired',
        applicationExpired: true,
      );
      onToast('Seat ${seatIndex + 1} is already occupied');
      onChanged();
      return;
    }

    final applicantId = latestEntry.senderId;
    if (applicantId == null || applicantId.trim().isEmpty) {
      messages[messageIndex] = latestEntry.copyWith(
        message: '${latestEntry.senderName} seat request expired',
        applicationExpired: true,
      );
      onChanged();
      return;
    }

    LiveRoomMediaSignalingService.instance.forceAssignSeat(
      targetUserId: applicantId,
      seatIndex: seatIndex,
    );

    messages[messageIndex] = latestEntry.copyWith(
      message: '${latestEntry.senderName} joined seat ${seatIndex + 1}',
      applicationApproved: true,
    );

    onChanged();
  }

  void rejectSeatApplication({
    required ChatEntry entry,
    required List<ChatEntry> messages,
  }) {
    if (!_currentUserIsAdminOrOwner) {
      onToast('Only the owner or room admins can reject seat requests');
      return;
    }
    final index = messages.indexOf(entry);
    if (index < 0) return;
    final latestEntry = messages[index];
    if (!latestEntry.isSeatApplication) return;
    if (latestEntry.applicationResolved) {
      onToast('This application has already been processed');
      return;
    }
    if (latestEntry.senderId != null) {
      _seatApplyCooldownUntil[latestEntry.senderId!] = DateTime.now().add(
        seatApplicationCooldown,
      );
      final seatIndex = latestEntry.seatIndex;
      if (seatIndex != null) {
        LiveRoomMediaSignalingService.instance.rejectSeatApplication(
          targetUserId: latestEntry.senderId!,
          seatIndex: seatIndex,
        );
      }
    }
    messages[index] = latestEntry.copyWith(
      message:
          '${latestEntry.senderName} seat ${latestEntry.seatIndex == null ? '' : latestEntry.seatIndex! + 1} request rejected',
      applicationRejected: true,
    );
    onChanged();
  }

  void switchSeat(int index) => occupySeat(index);

  void lockSeat(int index) {
    if (!_currentUserIsAdminOrOwner) {
      onToast('Only the owner or room admins can lock seats');
      return;
    }
    if (index < 0 || index >= seats.length) return;
    final wasCurrentUserSeat = _sameRoomUserId(
      seats[index].user?.id,
      currentUser.id,
    );
    seats[index] = seats[index].copyWith(locked: true, clearUser: true);
    selectedSeatIndex = null;
    LiveRoomMediaSignalingService.instance.lockSeat(seatIndex: index);
    if (wasCurrentUserSeat) LiveRoomMediaSignalingService.instance.leaveSeat();
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
    final target = _findRoomParticipant(userId);
    if (target == null || !_canRemoveTarget(target)) {
      onToast('You cannot remove this user');
      return;
    }
    selectedSeatIndex = null;
    LiveRoomMediaSignalingService.instance.kickUser(targetUserId: userId);
  }

  void kickUserFromRoom({required String userId, required String duration}) {
    final target = _findRoomParticipant(userId);
    if (target == null || !_canRemoveTarget(target)) {
      onToast('You cannot kick this user');
      return;
    }
    selectedSeatIndex = null;
    LiveRoomMediaSignalingService.instance.kickUser(
      targetUserId: userId,
      duration: duration,
    );
  }

  void toggleMic() {
    final index = seats.indexWhere(
      (seat) => _sameRoomUserId(seat.user?.id, currentUser.id),
    );
    final localUser = index >= 0 ? seats[index].user : null;
    if (localUser == null) return;
    if (localUser.adminMuted) {
      LiveRoomMediaSignalingService.instance.setMicEnabled(false);
      onToast('You are muted by the room admin');
      return;
    }
    final nextMuted = !localUser.selfMuted;
    LiveRoomMediaSignalingService.instance.setMicEnabled(!nextMuted);
  }

  void toggleSelfMute(String userId) {
    final index = seats.indexWhere(
      (seat) => _sameRoomUserId(seat.user?.id, userId),
    );
    if (index < 0) return;
    final user = seats[index].user!;
    if (!_sameRoomUserId(user.id, currentUser.id)) {
      onToast('You can only mute your own mic');
      return;
    }
    if (user.adminMuted) {
      LiveRoomMediaSignalingService.instance.setMicEnabled(false);
      onToast('You are muted by the room admin');
      return;
    }
    final nextMuted = !user.selfMuted;
    LiveRoomMediaSignalingService.instance.setMicEnabled(!nextMuted);
  }

  void toggleAdminMute(String userId) {
    final index = seats.indexWhere(
      (seat) => _sameRoomUserId(seat.user?.id, userId),
    );
    if (index < 0) return;
    final user = seats[index].user!;
    if (!_canAdminMuteTarget(user)) {
      onToast('You cannot mute or unmute this user');
      return;
    }
    final nextMuted = !user.adminMuted;
    LiveRoomMediaSignalingService.instance.setAdminMute(
      targetUserId: userId,
      muted: nextMuted,
    );
  }

  void setUserAsAdmin(String userId) {
    final target = _findRoomParticipant(userId);
    if (!_currentUserIsOwner ||
        target == null ||
        !canSetOrRemoveAdminFor(target)) {
      onToast('Only the room owner can set admins');
      return;
    }
    final promoted = target.copyWith(isRoomAdmin: true, roleLabel: 'Admin');
    _publishParticipantRole(promoted);
    LiveRoomMediaSignalingService.instance.setRoomAdminStatus(
      targetUserId: userId,
      isRoomAdmin: true,
    );
    onChanged();
    final publicUserId = _publicUserIdFromRoomUserId(userId);
    final roomId = LiveRoomMediaSignalingService.instance.roomId;
    if (publicUserId == null || roomId == null || roomId.trim().isEmpty) {
      onToast('${target.name} is now Admin');
      return;
    }
    unawaited(
      _presenceRepository
          .addRoomAdmin(roomId: roomId, publicUserId: publicUserId)
          .then((serverUser) {
            _publishParticipantRole(
              serverUser.copyWith(isRoomAdmin: true, roleLabel: 'Admin'),
            );
            onChanged();
          })
          .catchError((Object error) {
            onToast(error.toString().replaceFirst('Exception: ', ''));
          }),
    );
    onToast('${target.name} is now Admin');
  }

  void removeUserAsAdmin(String userId) {
    final target = _findRoomParticipant(userId);
    if (!_currentUserIsOwner ||
        target == null ||
        !canSetOrRemoveAdminFor(target)) {
      onToast('Only the room owner can remove admins');
      return;
    }
    final demoted = target.copyWith(isRoomAdmin: false, roleLabel: 'Member');
    _publishParticipantRole(demoted);
    LiveRoomMediaSignalingService.instance.setRoomAdminStatus(
      targetUserId: userId,
      isRoomAdmin: false,
    );
    onChanged();
    final publicUserId = _publicUserIdFromRoomUserId(userId);
    final roomId = LiveRoomMediaSignalingService.instance.roomId;
    if (publicUserId == null || roomId == null || roomId.trim().isEmpty) {
      onToast('${target.name} is no longer Admin');
      return;
    }
    unawaited(
      _presenceRepository
          .removeRoomAdmin(roomId: roomId, publicUserId: publicUserId)
          .then((serverUser) {
            _publishParticipantRole(
              serverUser.copyWith(isRoomAdmin: false, roleLabel: 'Member'),
            );
            onChanged();
          })
          .catchError((Object error) {
            onToast(error.toString().replaceFirst('Exception: ', ''));
          }),
    );
    onToast('${target.name} is no longer Admin');
  }

  void leaveAndLockSeat(int seatIndex) {
    if (seatIndex < 0 || seatIndex >= seats.length) return;
    final seatedUser = seats[seatIndex].user;
    if (seatedUser != null && _sameRoomUserId(seatedUser.id, currentUser.id)) {
      LiveRoomMediaSignalingService.instance.leaveSeat();
      return;
    }
    if (!_currentUserIsAdminOrOwner) {
      onToast('Only the owner or room admins can leave-lock seats');
      return;
    }
    if (seatedUser != null && !_canRemoveTarget(seatedUser)) {
      onToast('You cannot leave-lock this user');
      return;
    }
    if (seatedUser != null) {
      LiveRoomMediaSignalingService.instance.leaveAndLockSeat(
        seatIndex: seatIndex,
        targetUserId: seatedUser.id,
      );
    } else {
      LiveRoomMediaSignalingService.instance.lockSeat(seatIndex: seatIndex);
    }
  }

  void leaveSeatOnly(int seatIndex) {
    if (seatIndex < 0 || seatIndex >= seats.length) return;
    final seatedUser = seats[seatIndex].user;
    if (seatedUser == null) return;
    if (_sameRoomUserId(seatedUser.id, currentUser.id)) {
      LiveRoomMediaSignalingService.instance.leaveSeat();
      return;
    }
    if (!_currentUserIsAdminOrOwner) {
      onToast('Only the owner or room admins can remove users from seats');
      return;
    }
    if (!_canRemoveTarget(seatedUser)) {
      onToast('You cannot remove this user from seat');
      return;
    }
    LiveRoomMediaSignalingService.instance.forceLeaveSeat(
      seatIndex: seatIndex,
      targetUserId: seatedUser.id,
    );
  }

  bool _peerMatchesUser(LiveMediaPeerSnapshot peer, SeatUser user) {
    return _sameRoomUserId(peer.userId, user.id) ||
        _sameRoomUserId(peer.peerId, user.id);
  }

  bool _sameRoomUserId(String? a, String? b) {
    if (a == null || b == null) return false;
    final aliasesA = _identityAliases(a);
    final aliasesB = _identityAliases(b);
    if (aliasesA.isEmpty || aliasesB.isEmpty) return false;
    return aliasesA.intersection(aliasesB).isNotEmpty;
  }

  Set<String> _peerAliases(LiveMediaPeerSnapshot peer) {
    return <String>{
      ..._identityAliases(peer.userId),
      ..._identityAliases(peer.peerId),
    };
  }

  Set<String> _identityAliases(String rawId) {
    final value = rawId.trim();
    if (value.isEmpty) return <String>{};
    final aliases = <String>{value, value.toLowerCase()};
    final publicId = _publicUserIdFromAny(value);
    if (publicId != null) {
      aliases.add(publicId.toString());
      aliases.add('user_$publicId');
    }
    final userPrefix = RegExp(r'^user_(\d+)$').firstMatch(value);
    if (userPrefix != null) {
      aliases.add(userPrefix.group(1)!);
    }
    return aliases;
  }

  int? _publicUserIdFromAny(String rawId) {
    final value = rawId.trim();
    if (value.isEmpty) return null;
    final userMatch = RegExp(r'(?:^|_)user_(\d+)$').firstMatch(value);
    if (userMatch != null) return int.tryParse(userMatch.group(1)!);
    final direct = int.tryParse(value);
    if (direct != null && value.length >= 7) return direct;
    return null;
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
