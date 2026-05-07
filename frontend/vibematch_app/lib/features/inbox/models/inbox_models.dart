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

enum InboxMessageType {
  text,
  image,
  voice,
  document,
  location,
  contact,
  roomInvite,
  system;
}

enum InboxMessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed;
}

enum InboxReportStatus {
  pendingCsReview('Pending CS review'),
  rejectedByCs('Rejected by CS'),
  acceptedEscalated('Accepted • Sent to Monitor'),
  monitorActionTaken('Monitor action taken');

  const InboxReportStatus(this.label);

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
    this.isMuted = false,
    this.isPinned = false,
    this.isArchived = false,
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
  final bool isMuted;
  final bool isPinned;
  final bool isArchived;

  bool get isOfficial => type == InboxConversationType.official;
  bool get isStranger => type == InboxConversationType.stranger;
  bool get isRoomInvite => type == InboxConversationType.roomInvite;
  bool get isMutualFollowChat => type == InboxConversationType.chat && !isStranger;

  InboxConversation copyWith({
    String? subtitle,
    String? time,
    int? unreadCount,
    List<InboxMessage>? messages,
    bool? isLockedByBackend,
    bool? isBlocked,
    bool? isMuted,
    bool? isPinned,
    bool? isArchived,
  }) {
    return InboxConversation(
      id: id,
      title: title,
      subtitle: subtitle ?? this.subtitle,
      time: time ?? this.time,
      avatarText: avatarText,
      type: type,
      unreadCount: unreadCount ?? this.unreadCount,
      isOnline: isOnline,
      lastSeenText: lastSeenText,
      colors: colors,
      messages: messages ?? this.messages,
      currentRoomName: currentRoomName,
      isLockedByBackend: isLockedByBackend ?? this.isLockedByBackend,
      isBlocked: isBlocked ?? this.isBlocked,
      isMuted: isMuted ?? this.isMuted,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}

class InboxMessage {
  const InboxMessage({
    required this.sender,
    required this.text,
    required this.time,
    required this.isMine,
    this.id,
    this.type = InboxMessageType.text,
    this.status = InboxMessageStatus.read,
    this.reaction,
    this.replyToText,
    this.isStarred = false,
    this.isForwarded = false,
    this.inviteRoomName,
  });

  final String? id;
  final String sender;
  final String text;
  final String time;
  final bool isMine;
  final InboxMessageType type;
  final InboxMessageStatus status;
  final String? reaction;
  final String? replyToText;
  final bool isStarred;
  final bool isForwarded;
  final String? inviteRoomName;

  bool get isInvite => inviteRoomName != null || type == InboxMessageType.roomInvite;

  InboxMessage copyWith({
    String? id,
    String? sender,
    String? text,
    String? time,
    bool? isMine,
    InboxMessageType? type,
    InboxMessageStatus? status,
    String? reaction,
    bool clearReaction = false,
    String? replyToText,
    bool clearReply = false,
    bool? isStarred,
    bool? isForwarded,
    String? inviteRoomName,
  }) {
    return InboxMessage(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      text: text ?? this.text,
      time: time ?? this.time,
      isMine: isMine ?? this.isMine,
      type: type ?? this.type,
      status: status ?? this.status,
      reaction: clearReaction ? null : reaction ?? this.reaction,
      replyToText: clearReply ? null : replyToText ?? this.replyToText,
      isStarred: isStarred ?? this.isStarred,
      isForwarded: isForwarded ?? this.isForwarded,
      inviteRoomName: inviteRoomName ?? this.inviteRoomName,
    );
  }
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

class InboxReportTask {
  const InboxReportTask({
    required this.id,
    required this.reportedConversationId,
    required this.reportedUserName,
    required this.reporterName,
    required this.reason,
    required this.snapshot,
    required this.createdAtLabel,
    required this.status,
    this.csNote,
    this.monitorAction,
  });

  final String id;
  final String reportedConversationId;
  final String reportedUserName;
  final String reporterName;
  final String reason;
  final List<InboxMessage> snapshot;
  final String createdAtLabel;
  final InboxReportStatus status;
  final String? csNote;
  final String? monitorAction;

  bool get isPending => status == InboxReportStatus.pendingCsReview;

  InboxReportTask copyWith({
    InboxReportStatus? status,
    String? csNote,
    String? monitorAction,
  }) {
    return InboxReportTask(
      id: id,
      reportedConversationId: reportedConversationId,
      reportedUserName: reportedUserName,
      reporterName: reporterName,
      reason: reason,
      snapshot: snapshot,
      createdAtLabel: createdAtLabel,
      status: status ?? this.status,
      csNote: csNote ?? this.csNote,
      monitorAction: monitorAction ?? this.monitorAction,
    );
  }
}
