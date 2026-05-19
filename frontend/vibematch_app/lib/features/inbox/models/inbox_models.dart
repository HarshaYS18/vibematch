import 'package:flutter/material.dart';

import '../../../shared/communication/vm_communication_models.dart';

enum InboxConversationType {
  official('Official'),
  chat('Chat'),
  roomInvite('Room Invite'),
  stranger('Stranger'),
  group('Group'),
  storyReply('Story Reply'),
  callLog('Call');

  const InboxConversationType(this.label);

  final String label;
}

enum ChatBackupFrequency {
  daily('Daily', 'daily'),
  weekly('Weekly', 'weekly'),
  monthly('Monthly', 'monthly'),
  manual('Manual only', 'manual');

  const ChatBackupFrequency(this.label, this.apiValue);

  final String label;
  final String apiValue;

  static ChatBackupFrequency fromApi(String? value) {
    return ChatBackupFrequency.values.firstWhere(
      (item) => item.apiValue == value,
      orElse: () => ChatBackupFrequency.weekly,
    );
  }
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
  relationshipRequest,
  system,
  storyReply,
  callLog,
}

enum InboxMessageStatus { sending, sent, delivered, read, failed }

enum InboxReportStatus {
  pendingCsReview('Pending CS review'),
  rejectedByCs('Rejected by CS'),
  acceptedEscalated('Accepted • Sent to Monitor'),
  monitorActionTaken('Monitor action taken');

  const InboxReportStatus(this.label);

  final String label;
}

class InboxLockStatus {
  const InboxLockStatus({
    required this.isEnabled,
    this.mobileNumber,
    this.recoveryRequested = false,
  });

  final bool isEnabled;
  final String? mobileNumber;
  final bool recoveryRequested;

  InboxLockStatus copyWith({
    bool? isEnabled,
    String? mobileNumber,
    bool? recoveryRequested,
  }) {
    return InboxLockStatus(
      isEnabled: isEnabled ?? this.isEnabled,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      recoveryRequested: recoveryRequested ?? this.recoveryRequested,
    );
  }
}

class InboxBackupStatus {
  const InboxBackupStatus({
    required this.isEnabled,
    required this.isAuthorized,
    required this.provider,
    required this.frequency,
    required this.lastStatus,
    this.googleDriveEmail,
    this.googleDriveFolderId,
    this.lastBackupAt,
    this.lastRestoreAt,
    this.lastError,
    this.backupCount = 0,
    this.restoreCount = 0,
  });

  final bool isEnabled;
  final bool isAuthorized;
  final String provider;
  final ChatBackupFrequency frequency;
  final String lastStatus;
  final String? googleDriveEmail;
  final String? googleDriveFolderId;
  final String? lastBackupAt;
  final String? lastRestoreAt;
  final String? lastError;
  final int backupCount;
  final int restoreCount;

  bool get isConnected => isAuthorized && googleDriveEmail != null;

  InboxBackupStatus copyWith({
    bool? isEnabled,
    bool? isAuthorized,
    String? provider,
    ChatBackupFrequency? frequency,
    String? lastStatus,
    String? googleDriveEmail,
    String? googleDriveFolderId,
    String? lastBackupAt,
    String? lastRestoreAt,
    String? lastError,
    int? backupCount,
    int? restoreCount,
  }) {
    return InboxBackupStatus(
      isEnabled: isEnabled ?? this.isEnabled,
      isAuthorized: isAuthorized ?? this.isAuthorized,
      provider: provider ?? this.provider,
      frequency: frequency ?? this.frequency,
      lastStatus: lastStatus ?? this.lastStatus,
      googleDriveEmail: googleDriveEmail ?? this.googleDriveEmail,
      googleDriveFolderId: googleDriveFolderId ?? this.googleDriveFolderId,
      lastBackupAt: lastBackupAt ?? this.lastBackupAt,
      lastRestoreAt: lastRestoreAt ?? this.lastRestoreAt,
      lastError: lastError ?? this.lastError,
      backupCount: backupCount ?? this.backupCount,
      restoreCount: restoreCount ?? this.restoreCount,
    );
  }
}

class InboxBackupJob {
  const InboxBackupJob({
    required this.id,
    required this.jobType,
    required this.provider,
    required this.status,
    this.backupFileId,
    this.backupFileName,
    this.errorMessage,
    this.createdAt,
    this.completedAt,
  });

  final String id;
  final String jobType;
  final String provider;
  final String status;
  final String? backupFileId;
  final String? backupFileName;
  final String? errorMessage;
  final String? createdAt;
  final String? completedAt;
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
    this.lastSeenAt,
    required this.colors,
    required this.messages,
    this.avatarUrl,
    this.currentRoomName,
    this.currentRoomId,
    this.roomPresence = const VmRoomPresenceSnapshot(),
    this.isLockedByBackend = false,
    this.isBlocked = false,
    this.isMuted = false,
    this.isPinned = false,
    this.isArchived = false,
    this.isStrangerHub = false,
    this.requestCount = 0,
    this.chatStreakCount = 0,
    this.chatStreakActiveToday = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final String time;
  final String avatarText;
  final String? avatarUrl;
  final InboxConversationType type;
  final int unreadCount;
  final bool isOnline;
  final String lastSeenText;
  final DateTime? lastSeenAt;
  final List<Color> colors;
  final List<InboxMessage> messages;
  final String? currentRoomName;
  final String? currentRoomId;
  final VmRoomPresenceSnapshot roomPresence;
  final bool isLockedByBackend;
  final bool isBlocked;
  final bool isMuted;
  final bool isPinned;
  final bool isArchived;
  final bool isStrangerHub;
  final int requestCount;
  final int chatStreakCount;
  final bool chatStreakActiveToday;

  bool get isOfficial => type == InboxConversationType.official;
  bool get isStranger => type == InboxConversationType.stranger;
  bool get isRoomInvite => type == InboxConversationType.roomInvite;
  bool get isGroup => type == InboxConversationType.group;
  bool get isStoryReply => type == InboxConversationType.storyReply;
  bool get isCallLog => type == InboxConversationType.callLog;
  bool get isMutualFollowChat => type == InboxConversationType.chat && !isStranger;
  bool get hasAvatarUrl => avatarUrl != null && avatarUrl!.trim().isNotEmpty;
  bool get hasChatStreak => chatStreakCount > 0;

  String get safePresenceText {
    final roomStatus = roomPresence.safeRoomStatusText;
    if (roomStatus != null) return roomStatus;
    if (isOnline) return 'online';
    return _localLastSeenText();
  }

  String _localLastSeenText() {
    final seen = lastSeenAt;
    if (seen == null) return lastSeenText;

    final now = DateTime.now();
    final timeLabel = _formatLocal12h(seen);

    if (_isSameDate(seen, now)) {
      return 'last seen at $timeLabel';
    }

    final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    if (_isSameDate(seen, yesterday)) {
      return 'last seen yesterday at $timeLabel';
    }

    return 'last seen ${_monthLabel(seen.month)} ${seen.day} at $timeLabel';
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatLocal12h(DateTime value) {
    final suffix = value.hour < 12 ? 'am' : 'pm';
    var hour = value.hour % 12;
    if (hour == 0) hour = 12;
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute $suffix';
  }

  String _monthLabel(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (month < 1 || month > 12) return '';
    return months[month - 1];
  }

  String get listPreviewText {
    if (isLockedByBackend) return 'Locked chat • tap to unlock';
    if (isStrangerHub) return '$requestCount message request${requestCount == 1 ? '' : 's'} waiting';
    return subtitle;
  }

  InboxConversation copyWith({
    String? title,
    String? subtitle,
    String? time,
    String? avatarText,
    String? avatarUrl,
    bool clearAvatarUrl = false,
    int? unreadCount,
    bool? isOnline,
    String? lastSeenText,
    DateTime? lastSeenAt,
    List<Color>? colors,
    List<InboxMessage>? messages,
    String? currentRoomName,
    String? currentRoomId,
    VmRoomPresenceSnapshot? roomPresence,
    bool? isLockedByBackend,
    bool? isBlocked,
    bool? isMuted,
    bool? isPinned,
    bool? isArchived,
    bool? isStrangerHub,
    int? requestCount,
    int? chatStreakCount,
    bool? chatStreakActiveToday,
  }) {
    return InboxConversation(
      id: id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      time: time ?? this.time,
      avatarText: avatarText ?? this.avatarText,
      avatarUrl: clearAvatarUrl ? null : avatarUrl ?? this.avatarUrl,
      type: type,
      unreadCount: unreadCount ?? this.unreadCount,
      isOnline: isOnline ?? this.isOnline,
      lastSeenText: lastSeenText ?? this.lastSeenText,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      colors: colors ?? this.colors,
      messages: messages ?? this.messages,
      currentRoomName: currentRoomName ?? this.currentRoomName,
      currentRoomId: currentRoomId ?? this.currentRoomId,
      roomPresence: roomPresence ?? this.roomPresence,
      isLockedByBackend: isLockedByBackend ?? this.isLockedByBackend,
      isBlocked: isBlocked ?? this.isBlocked,
      isMuted: isMuted ?? this.isMuted,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      isStrangerHub: isStrangerHub ?? this.isStrangerHub,
      requestCount: requestCount ?? this.requestCount,
      chatStreakCount: chatStreakCount ?? this.chatStreakCount,
      chatStreakActiveToday: chatStreakActiveToday ?? this.chatStreakActiveToday,
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
    this.inviteRoomId,
    this.loveBondRequestId,
    this.loveBondCardName,
    this.loveBondStatus,
    this.attachmentUrl,
    this.localAttachmentPath,
    this.mediaExpired = false,
    this.expiredMediaUrl,
    this.localFirstAllowed = false,
    this.createdAt,
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
  final String? inviteRoomId;
  final String? loveBondRequestId;
  final String? loveBondCardName;
  final String? loveBondStatus;
  final String? attachmentUrl;
  final String? localAttachmentPath;
  final bool mediaExpired;
  final String? expiredMediaUrl;
  final bool localFirstAllowed;
  final DateTime? createdAt;

  bool get canUnsend {
    final created = createdAt;
    if (!isMine || isSystem || created == null) return false;
    return DateTime.now().difference(created) <= const Duration(hours: 1);
  }

  bool get isInvite =>
      inviteRoomName != null ||
      inviteRoomId != null ||
      type == InboxMessageType.roomInvite;
  bool get isLoveBondRequest =>
      loveBondRequestId != null || type == InboxMessageType.relationshipRequest;
  bool get isSystem => type == InboxMessageType.system;
  bool get hasAttachmentUrl => attachmentUrl != null && attachmentUrl!.trim().isNotEmpty;
  bool get hasLocalAttachmentPath => localAttachmentPath != null && localAttachmentPath!.trim().isNotEmpty;
  String? get effectiveRemoteMediaUrl => attachmentUrl?.trim().isNotEmpty == true ? attachmentUrl!.trim() : expiredMediaUrl?.trim();

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
    String? inviteRoomId,
    String? loveBondRequestId,
    String? loveBondCardName,
    String? loveBondStatus,
    String? attachmentUrl,
    String? localAttachmentPath,
    bool? mediaExpired,
    String? expiredMediaUrl,
    bool? localFirstAllowed,
    DateTime? createdAt,
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
      inviteRoomId: inviteRoomId ?? this.inviteRoomId,
      loveBondRequestId: loveBondRequestId ?? this.loveBondRequestId,
      loveBondCardName: loveBondCardName ?? this.loveBondCardName,
      loveBondStatus: loveBondStatus ?? this.loveBondStatus,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      localAttachmentPath: localAttachmentPath ?? this.localAttachmentPath,
      mediaExpired: mediaExpired ?? this.mediaExpired,
      expiredMediaUrl: expiredMediaUrl ?? this.expiredMediaUrl,
      localFirstAllowed: localFirstAllowed ?? this.localFirstAllowed,
      createdAt: createdAt ?? this.createdAt,
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