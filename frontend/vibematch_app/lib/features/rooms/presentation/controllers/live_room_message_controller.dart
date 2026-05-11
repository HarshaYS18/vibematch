import 'dart:async';

import '../../data/live_room_media_signaling_service.dart';
import '../live_room_models.dart';

class LiveRoomMessageController {
  LiveRoomMessageController({
    required SeatUser currentUser,
    required this.onChanged,
  }) : currentUser = LiveRoomMediaSignalingService.instance.effectiveCurrentUser(currentUser) {
    messages = List<ChatEntry>.from(mockChatEntries);
    _activeController?._detachSnapshotListener();
    _activeController = this;
    _attachSnapshotListener();
  }

  static LiveRoomMessageController? _activeController;

  static void clearActiveRoomChatForEveryone() {
    _activeController?.clearChatForEveryone();
  }

  static void sendActiveRoomImageMessage({required String imageUrl, required String contentType}) {
    _activeController?.sendImageMessage(imageUrl: imageUrl, contentType: contentType);
  }

  static void recordActiveRoomMemberExit({required String actorName, required String memberUserId, required String memberName}) {
    _activeController?._recordPendingMemberExit(actorName: actorName, memberUserId: memberUserId, memberName: memberName);
  }

  final SeatUser currentUser;
  final VoidCallbackLike onChanged;

  late List<ChatEntry> messages;

  final List<SeatUser> joinRequestUsers = <SeatUser>[];
  final Set<String> _knownRoomUserIds = <String>{};
  final Map<String, String> _knownRoomNamesById = <String, String>{};
  final Map<String, _PendingMemberExitEvent> _pendingMemberExits = <String, _PendingMemberExitEvent>{};
  VoidCallbackLike? _snapshotListener;
  bool _snapshotSeeded = false;

  void sendMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    messages.insert(0, ChatEntry(senderName: currentUser.name, senderId: currentUser.id, message: trimmed, vipLevel: currentUser.vipLevel, sendingLevel: currentUser.sendingLevel, receivingLevel: currentUser.receivingLevel));
    onChanged();
  }

  void sendImageMessage({required String imageUrl, required String contentType}) {
    final safeUrl = imageUrl.trim();
    if (safeUrl.isEmpty) return;
    messages.insert(0, ChatEntry(senderName: currentUser.name, senderId: currentUser.id, message: 'sent an image', vipLevel: currentUser.vipLevel, sendingLevel: currentUser.sendingLevel, receivingLevel: currentUser.receivingLevel, imageUrl: safeUrl, imageContentType: contentType.trim().isEmpty ? 'image/jpeg' : contentType.trim()));
    onChanged();
  }

  void insertSystemMessage(String message) => insertPersistentSystemMessage(message);

  void insertPersistentSystemMessage(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;
    messages.insert(0, ChatEntry(senderName: 'System', senderId: 'system', message: trimmed));
    onChanged();
  }

  void insertUserEnteredSystemEvent(SeatUser user) => _insertUserEnteredByName(user.name);

  void insertUserRemovedSystemEvent({required String actorName, required String targetName}) {
    final actor = actorName.trim().isEmpty ? 'Room admin' : actorName.trim();
    final member = targetName.trim().isEmpty ? 'user' : targetName.trim();
    messages.insert(0, ChatEntry(senderName: 'System', senderId: 'system', message: '$actor has rem' 'oved $member from the group', systemEventType: RoomSystemEventType.userRemoved));
    onChanged();
  }

  void insertEntry(ChatEntry entry) {
    messages.insert(0, entry);
    if (entry.shouldAutoDismiss) _scheduleAutoDismiss(entry);
    onChanged();
  }

  void clearChatForEveryone() {
    messages.clear();
    insertPersistentSystemMessage('Chat cleared for everyone by ${currentUser.name}');
  }

  void requestJoin() {
    final alreadyRequested = joinRequestUsers.any((user) => user.id == currentUser.id);
    if (!alreadyRequested) {
      joinRequestUsers.add(currentUser);
      onChanged();
    }
  }

  void resolveJoinRequest({required SeatUser user, required bool approved, required String roomName}) {
    joinRequestUsers.removeWhere((item) => item.id == user.id);
    messages.insert(0, ChatEntry(senderName: currentUser.name, senderId: currentUser.id, message: approved ? 'approved ${user.name} to join $roomName' : 'rejected ${user.name}\'s join request', vipLevel: currentUser.vipLevel, sendingLevel: currentUser.sendingLevel, receivingLevel: currentUser.receivingLevel));
    onChanged();
  }

  void _recordPendingMemberExit({required String actorName, required String memberUserId, required String memberName}) {
    final memberId = memberUserId.trim();
    if (memberId.isEmpty) return;
    _pendingMemberExits[memberId] = _PendingMemberExitEvent(actorName: actorName.trim().isEmpty ? currentUser.name : actorName.trim(), memberName: memberName.trim().isEmpty ? (_knownRoomNamesById[memberId] ?? 'user') : memberName.trim(), createdAt: DateTime.now());
  }

  void _attachSnapshotListener() {
    _snapshotListener = _syncSystemEventsFromRoomSnapshot;
    LiveRoomMediaSignalingService.instance.roomSnapshot.addListener(_snapshotListener!);
  }

  void _detachSnapshotListener() {
    final listener = _snapshotListener;
    if (listener == null) return;
    LiveRoomMediaSignalingService.instance.roomSnapshot.removeListener(listener);
    _snapshotListener = null;
  }

  void _syncSystemEventsFromRoomSnapshot() {
    final snapshot = LiveRoomMediaSignalingService.instance.roomSnapshot.value;
    if (snapshot == null) return;
    final nextIds = <String>{};
    final nextNamesById = <String, String>{};
    for (final peer in snapshot.peers) {
      final id = peer.userId.trim();
      if (id.isEmpty) continue;
      nextIds.add(id);
      nextNamesById[id] = peer.displayName.trim().isEmpty ? 'User' : peer.displayName.trim();
    }
    _pruneStalePendingMemberExits();
    if (!_snapshotSeeded) {
      _knownRoomUserIds..clear()..addAll(nextIds);
      _knownRoomNamesById..clear()..addAll(nextNamesById);
      _snapshotSeeded = true;
      return;
    }
    for (final id in nextIds) {
      if (_knownRoomUserIds.contains(id) || id == currentUser.id) continue;
      _insertUserEnteredByName(nextNamesById[id] ?? 'User');
    }
    for (final id in _knownRoomUserIds) {
      if (nextIds.contains(id) || id == currentUser.id) continue;
      final pending = _pendingMemberExits.remove(id);
      insertUserRemovedSystemEvent(actorName: pending?.actorName ?? 'Room admin', targetName: pending?.memberName ?? _knownRoomNamesById[id] ?? 'user');
    }
    _knownRoomUserIds..clear()..addAll(nextIds);
    _knownRoomNamesById..clear()..addAll(nextNamesById);
  }

  void _insertUserEnteredByName(String rawName) {
    final name = rawName.trim().isEmpty ? 'User' : rawName.trim();
    final entry = ChatEntry(senderName: name, senderId: 'system', message: '$name Entered the Room', systemEventType: RoomSystemEventType.userEntered, autoDismissAt: DateTime.now().add(const Duration(seconds: 5)));
    messages.insert(0, entry);
    onChanged();
    _scheduleAutoDismiss(entry);
  }

  void _pruneStalePendingMemberExits() {
    final cutoff = DateTime.now().subtract(const Duration(seconds: 20));
    _pendingMemberExits.removeWhere((key, value) => value.createdAt.isBefore(cutoff));
  }

  void _scheduleAutoDismiss(ChatEntry entry) {
    final dismissAt = entry.autoDismissAt;
    if (dismissAt == null) return;
    final delay = dismissAt.difference(DateTime.now());
    Timer(delay.isNegative ? Duration.zero : delay, () {
      final removed = messages.remove(entry);
      if (removed) onChanged();
    });
  }
}

class _PendingMemberExitEvent {
  const _PendingMemberExitEvent({required this.actorName, required this.memberName, required this.createdAt});
  final String actorName;
  final String memberName;
  final DateTime createdAt;
}

typedef VoidCallbackLike = void Function();
typedef ValueChangedLike<T> = void Function(T value);
