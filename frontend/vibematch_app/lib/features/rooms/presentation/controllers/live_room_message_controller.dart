import 'dart:async';

import '../live_room_models.dart';

class LiveRoomMessageController {
  LiveRoomMessageController({
    required this.currentUser,
    required this.onChanged,
  }) {
    messages = List<ChatEntry>.from(mockChatEntries);
    _activeController = this;
  }

  static LiveRoomMessageController? _activeController;

  static void clearActiveRoomChatForEveryone() {
    _activeController?.clearChatForEveryone();
  }

  final SeatUser currentUser;
  final VoidCallbackLike onChanged;

  late List<ChatEntry> messages;

  final List<SeatUser> joinRequestUsers = <SeatUser>[
    mockInviteUsers[0],
    mockInviteUsers[1],
  ];

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

  void insertSystemMessage(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;

    _insertAutoClearSystemMessage(trimmed);
  }

  void insertEntry(ChatEntry entry) {
    messages.insert(0, entry);
    onChanged();
  }

  void clearChatForEveryone() {
    messages.clear();
    _insertAutoClearSystemMessage('Chat cleared for everyone by ${currentUser.name}');
  }

  void requestJoin() {
    final alreadyRequested = joinRequestUsers.any(
      (user) => user.id == currentUser.id,
    );

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
        message: approved
            ? 'approved ${user.name} to join $roomName'
            : 'rejected ${user.name}\'s join request',
        vipLevel: currentUser.vipLevel,
        sendingLevel: currentUser.sendingLevel,
        receivingLevel: currentUser.receivingLevel,
      ),
    );

    onChanged();
  }

  void _insertAutoClearSystemMessage(String message) {
    final entry = ChatEntry(
      senderName: 'System',
      senderId: 'system',
      message: message,
    );

    messages.insert(0, entry);
    onChanged();

    Timer(const Duration(seconds: 5), () {
      final removed = messages.remove(entry);
      if (removed) onChanged();
    });
  }
}

typedef VoidCallbackLike = void Function();
typedef ValueChangedLike<T> = void Function(T value);
