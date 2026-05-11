import 'dart:async';

import '../../data/live_room_media_signaling_service.dart';
import '../../data/live_room_system_event_bus.dart';
import '../live_room_models.dart';

class LiveRoomMessageController {
  LiveRoomMessageController({
    required SeatUser currentUser,
    required this.onChanged,
  }) : currentUser = LiveRoomMediaSignalingService.instance.effectiveCurrentUser(currentUser) {
    messages = List<ChatEntry>.from(mockChatEntries);
    _activeController?._detachSystemEventListener();
    _activeController = this;
    _attachSystemEventListener();
  }

  static LiveRoomMessageController? _activeController;

  static void clearActiveRoomChatForEveryone() {
    _activeController?.clearChatForEveryone();
  }

  static void sendActiveRoomImageMessage({required String imageUrl, required String contentType}) {
    _activeController?.sendImageMessage(imageUrl: imageUrl, contentType: contentType);
  }

  final SeatUser currentUser;
  final VoidCallbackLike onChanged;

  late List<ChatEntry> messages;

  final List<SeatUser> joinRequestUsers = <SeatUser>[];
  final Set<String> _handledSystemEventIds = <String>{};
  VoidCallbackLike? _systemEventListener;

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
    messages.insert(0, ChatEntry(senderName: 'System', senderId: 'system', message: '$actor has removed $member from the group', systemEventType: RoomSystemEventType.userRemoved));
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

  void _attachSystemEventListener() {
    _systemEventListener = _handleLatestMediaSystemEvent;
    LiveRoomSystemEventBus.latestEvent.addListener(_systemEventListener!);
  }

  void _detachSystemEventListener() {
    final listener = _systemEventListener;
    if (listener == null) return;
    LiveRoomSystemEventBus.latestEvent.removeListener(listener);
    _systemEventListener = null;
  }

  void _handleLatestMediaSystemEvent() {
    final event = LiveRoomSystemEventBus.latestEvent.value;
    if (event == null || _handledSystemEventIds.contains(event.id)) return;
    _handledSystemEventIds.add(event.id);

    if (event.isUserEntered) {
      if (event.targetUserId == currentUser.id || event.actorUserId == currentUser.id) return;
      final name = event.targetName.trim().isNotEmpty ? event.targetName : event.actorName;
      _insertUserEnteredByName(name);
      return;
    }

    if (event.isUserRemoved) {
      if (event.targetUserId == currentUser.id) return;
      insertUserRemovedSystemEvent(actorName: event.actorName, targetName: event.targetName);
    }
  }

  void _insertUserEnteredByName(String rawName) {
    final name = rawName.trim().isEmpty ? 'User' : rawName.trim();
    final entry = ChatEntry(senderName: name, senderId: 'system', message: '$name Entered the Room', systemEventType: RoomSystemEventType.userEntered, autoDismissAt: DateTime.now().add(const Duration(seconds: 5)));
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
