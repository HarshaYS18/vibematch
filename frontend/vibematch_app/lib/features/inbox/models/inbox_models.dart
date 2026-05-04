import 'package:flutter/material.dart';

enum InboxConversationType {
  official('Official'),
  chat('Chat'),
  roomInvite('Room Invite'),
  stranger('Stranger');

  const InboxConversationType(this.label);

  final String label;
}

enum ChatBackupFrequency {
  daily('Daily'),
  weekly('Weekly'),
  monthly('Monthly'),
  manual('Manual only');

  const ChatBackupFrequency(this.label);

  final String label;
}

enum InboxSearchMatchType {
  chat('Chats'),
  mutualFollow('Friends'),
  message('Messages');

  const InboxSearchMatchType(this.label);

  final String label;
}

class InboxConversation {
  const InboxConversation({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.avatarText,
    required this.type,
    required this.unreadCount,
    required this.isOnline,
    required this.lastSeenText,
    required this.colors,
    required this.messages,
    this.currentRoomName,
    this.isLockedByBackend = false,
    this.isBlocked = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final String time;
  final String avatarText;
  final InboxConversationType type;
  final int unreadCount;
  final bool isOnline;
  final String lastSeenText;
  final List<Color> colors;
  final List<InboxMessage> messages;
  final String? currentRoomName;
  final bool isLockedByBackend;
  final bool isBlocked;

  bool get isOfficial => type == InboxConversationType.official;
  bool get isStranger => type == InboxConversationType.stranger;
  bool get isRoomInvite => type == InboxConversationType.roomInvite;
  bool get isMutualFollowChat => type == InboxConversationType.chat && !isStranger;

  InboxConversation copyWith({
    bool? isLockedByBackend,
    bool? isBlocked,
  }) {
    return InboxConversation(
      id: id,
      title: title,
      subtitle: subtitle,
      time: time,
      avatarText: avatarText,
      type: type,
      unreadCount: unreadCount,
      isOnline: isOnline,
      lastSeenText: lastSeenText,
      colors: colors,
      messages: messages,
      currentRoomName: currentRoomName,
      isLockedByBackend: isLockedByBackend ?? this.isLockedByBackend,
      isBlocked: isBlocked ?? this.isBlocked,
    );
  }
}

class InboxMessage {
  const InboxMessage({
    required this.sender,
    required this.text,
    required this.time,
    required this.isMine,
    this.inviteRoomName,
  });

  final String sender;
  final String text;
  final String time;
  final bool isMine;
  final String? inviteRoomName;
}

class InboxSearchResult {
  const InboxSearchResult({
    required this.conversation,
    required this.matchType,
    required this.title,
    required this.preview,
    required this.matchedText,
    this.message,
  });

  final InboxConversation conversation;
  final InboxSearchMatchType matchType;
  final String title;
  final String preview;
  final String matchedText;
  final InboxMessage? message;
}
