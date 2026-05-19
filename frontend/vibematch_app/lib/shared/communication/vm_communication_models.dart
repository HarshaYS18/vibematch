import 'package:flutter/foundation.dart';

/// Canonical communication contracts shared by Inbox, calls, notifications,
/// stories, groups, and future realtime layers.
///
/// Feature modules should import and compose these models instead of defining
/// duplicate call-state, notification-payload, quick-reply, or presence types.
enum VmConversationSurface {
  directChat,
  groupChat,
  strangerRequest,
  roomInvite,
  storyReply,
  teamSystem,
  callLog,
}

enum VmPresenceVisibility {
  visible,
  hiddenByUser,
  hiddenBySecretVibe,
  hiddenByStealthOfficial,
  blocked,
}

@immutable
class VmRoomPresenceSnapshot {
  const VmRoomPresenceSnapshot({
    this.roomPublicId,
    this.roomName,
    this.isSecretVibe = false,
    this.isStealthPresence = false,
    this.visibility = VmPresenceVisibility.visible,
  });

  final String? roomPublicId;
  final String? roomName;
  final bool isSecretVibe;
  final bool isStealthPresence;
  final VmPresenceVisibility visibility;

  bool get canRevealRoomName {
    return roomName != null &&
        roomName!.trim().isNotEmpty &&
        !isSecretVibe &&
        !isStealthPresence &&
        visibility == VmPresenceVisibility.visible;
  }

  String? get safeRoomStatusText {
    if (!canRevealRoomName) return null;
    return 'In chatroom: ${roomName!.trim()}';
  }

  factory VmRoomPresenceSnapshot.fromJson(Map<String, dynamic> json) {
    final visibilityValue = json['visibility']?.toString();
    return VmRoomPresenceSnapshot(
      roomPublicId: _nullableString(json['room_public_id'] ?? json['room_id']),
      roomName: _nullableString(json['room_name'] ?? json['current_room_name']),
      isSecretVibe: json['is_secret_vibe'] == true,
      isStealthPresence: json['is_stealth_presence'] == true,
      visibility: VmPresenceVisibility.values.firstWhere(
        (item) => item.name == visibilityValue,
        orElse: () => VmPresenceVisibility.visible,
      ),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'room_public_id': roomPublicId,
        'room_name': roomName,
        'is_secret_vibe': isSecretVibe,
        'is_stealth_presence': isStealthPresence,
        'visibility': visibility.name,
      };
}

enum VmCallType { audio, video, groupAudio, groupVideo }

enum VmCallStatus {
  idle,
  ringing,
  connecting,
  active,
  declined,
  missed,
  ended,
  failed,
  cancelled,
}

@immutable
class VmCallParticipantRef {
  const VmCallParticipantRef({
    required this.publicUserId,
    required this.displayName,
    this.avatarUrl,
    this.isMuted = false,
    this.isCameraEnabled = true,
  });

  final int publicUserId;
  final String displayName;
  final String? avatarUrl;
  final bool isMuted;
  final bool isCameraEnabled;
}

@immutable
class VmCallSessionRef {
  const VmCallSessionRef({
    required this.callId,
    required this.type,
    required this.status,
    required this.startedByPublicUserId,
    required this.participants,
    this.conversationId,
    this.startedAt,
    this.endedAt,
    this.durationSeconds,
  });

  final String callId;
  final String? conversationId;
  final VmCallType type;
  final VmCallStatus status;
  final int startedByPublicUserId;
  final List<VmCallParticipantRef> participants;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;

  bool get isVideo => type == VmCallType.video || type == VmCallType.groupVideo;
  bool get isGroup => type == VmCallType.groupAudio || type == VmCallType.groupVideo;
}

enum VmNotificationPayloadType {
  message,
  roomInvite,
  teamSystem,
  strangerRequest,
  call,
  storyReply,
}

@immutable
class VmNotificationPayload {
  const VmNotificationPayload({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.conversationId,
    this.messageId,
    this.callId,
    this.roomPublicId,
    this.senderPublicUserId,
    this.metadata = const <String, Object?>{},
  });

  final String id;
  final VmNotificationPayloadType type;
  final String title;
  final String body;
  final String? conversationId;
  final String? messageId;
  final String? callId;
  final String? roomPublicId;
  final int? senderPublicUserId;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'type': type.name,
        'title': title,
        'body': body,
        'conversation_id': conversationId,
        'message_id': messageId,
        'call_id': callId,
        'room_public_id': roomPublicId,
        'sender_public_user_id': senderPublicUserId,
        'metadata': metadata,
      };
}

@immutable
class VmQuickReplyPayload {
  const VmQuickReplyPayload({
    required this.notificationId,
    required this.conversationId,
    required this.replyText,
    this.messageId,
  });

  final String notificationId;
  final String conversationId;
  final String? messageId;
  final String replyText;

  Map<String, Object?> toJson() => <String, Object?>{
        'notification_id': notificationId,
        'conversation_id': conversationId,
        'message_id': messageId,
        'reply_text': replyText,
      };
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty || text == 'null') return null;
  return text;
}
