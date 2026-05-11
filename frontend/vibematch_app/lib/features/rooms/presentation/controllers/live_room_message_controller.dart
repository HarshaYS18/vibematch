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

  static void sendActiveRoomImageMessage({
    required String imageUrl,
    required String contentType,
  }) {
    _activeController?.sendImageMessage(imageUrl: imageUrl, contentType: contentType);
  }

  final SeatUser currentUser;
  final VoidCallbackLike onChanged;

  late List<ChatEntry> messages;

  final List<SeatUser> joinRequestUsers = <SeatUser>[];
  final Set<String> _knownRoomUserIds = <String>{};
  VoidCallbackLike? _snapshotListener;
  bool _snapshotSeeded = false;

  void sendMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    messages.insert(
      0,
      ChatEntry(
        senderName: currentUser.name,
        senderId: currentUser.id,
        message: trimmed,
        vipLevel: currentUser.vipLevel,
        sendingLevel: currentUser.sendingLevel,
        receivingLevel: currentUser.receivingLevel,
      ),
    );

    onChanged();
  }

  void sendImageMessage({
    required String imageUrl,
    required String contentType,
  }) {
    final safeUrl = imageUrl.trim();
    if (safeUrl.isEmpty) return;

    messages.insert(
      0,
      ChatEntry(
        senderName: currentUser.name,
        senderId: currentUser.id,
        message: 'sent an image',
        vipLevel: currentUser.vipLevel,
        sendingLevel: currentUser.sendingLevel,
        receivingLevel: currentUser.receivingLevel,
        imageUrl: safeUrl,
        imageContentType: contentType.trim().isEmpty ? 'image/jpeg' : contentType.trim(),
      ),
    );

    onChanged();
  }

  void insertSystemMessage(String message) {
    insertPersistentSystemMessage(message);
  }

  void insertPersistentSystemMessage(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;

    messages.insert(
      0,
      ChatEntry(
        senderName: 'System',
        senderId: 'system',
        message: trimmed,
      ),
    );

    onChanged();
  }

  void insertUserEnteredSystemEvent(SeatUser user) {
    _insertUserEnteredByName(user.name);
  }

  void insertUserRemovedSystemEvent({
    required String actorName,
    required String targetName,
  }) {
    final actor = actorName.trim().isEmpty ? 'Admin' : actorName.trim();
    final target = targetName.trim().isEmpty ? 'user' : targetName.trim();
    messages.insert(
      0,
      ChatEntry(
        senderName: 'System',
        senderId: 'system',
        message: '$actor has removed $target from the group',
        systemEventType: RoomSystemEventType.userRemoved,
      ),
    );
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

  void resolveJoinRequest({
    required SeatUser user,
    required bool approved,
    required String roomName,
  }) {
    joinRequestUsers.removeWhere((item) => item.id == user.id);

    messages.insert(
      0,
      ChatEntry(
        senderName: currentUser.name,
        senderId: currentUser.id,
        message: approved ? 'approved ${user.name} to join $roomName' : 'rejected ${user.name}\'s join request',
        vipLevel: currentUser.vipLevel,
        sendingLevel: currentUser.sendingLevel,
        receivingLevel: currentUser.receivingLevel,
      ),
    );

    onChanged();
  }

  void _attachSnapshotListener() {
    _snapshotListener = _syncEntryEventsFromRoomSnapshot;
    LiveRoomMediaSignalingService.instance.roomSnapshot.addListener(_snapshotListener!);
  }

  void _detachSnapshotListener() {
    final listener = _snapshotListener;
    if (listener == null) return;
    LiveRoomMediaSignalingService.instance.roomSnapshot.removeListener(listener);
    _snapshotListener = null;
  }

  void _syncEntryEventsFromRoomSnapshot() {
    final snapshot = LiveRoomMediaSignalingService.instance.roomSnapshot.value;
    if (snapshot == null) return;

    final nextIds = <String>{};
    final namesById = <String, String>{};
    for (final peer in snapshot.peers) {
      final id = peer.userId.trim();
      if (id.isEmpty) continue;
      nextIds.add(id);
      namesById[id] = peer.displayName.trim().isEmpty ? 'User' : peer.displayName.trim();
    }

    if (!_snapshotSeeded) {
      _knownRoomUserIds
        ..clear()
        ..addAll(nextIds);
      _snapshotSeeded = true;
      return;
    }

    for (final id in nextIds) {
      if (_knownRoomUserIds.contains(id) || id == currentUser.id) continue;
      _insertUserEnteredByName(namesById[id] ?? 'User');
    }

    _knownRoomUserIds
      ..clear()
      ..addAll(nextIds);
  }

  void _insertUserEnteredByName(String rawName) {
    final name = rawName.trim().isEmpty ? 'User' : rawName.trim();
    final entry = ChatEntry(
      senderName: name,
      senderId: 'system',
      message: '$name Entered the Room',
      systemEventType: RoomSystemEventType.userEntered,
      autoDismissAt: DateTime.now().add(const Duration(seconds: 5)),
    );
    messages.insert(0, entry);
    onChanged();
    _scheduleAutoDismiss(entry);
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

typedef VoidCallbackLike = void Function();
typedef ValueChangedLike<T> = void Function(T value);
