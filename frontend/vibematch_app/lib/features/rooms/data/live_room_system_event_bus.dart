import 'package:flutter/foundation.dart';

class LiveRoomSystemEventBus {
  LiveRoomSystemEventBus._();

  static final ValueNotifier<LiveRoomSystemEvent?> latestEvent =
      ValueNotifier<LiveRoomSystemEvent?>(null);

  static void publish(LiveRoomSystemEvent event) {
    latestEvent.value = event;
  }
}

class LiveRoomSystemEvent {
  const LiveRoomSystemEvent({
    required this.id,
    required this.type,
    required this.roomId,
    required this.actorUserId,
    required this.actorName,
    required this.targetUserId,
    required this.targetName,
    required this.createdAt,
    this.message = '',
    this.actorAvatarUrl,
    this.actorVipLevel = 0,
    this.actorSendingLevel = 0,
    this.actorReceivingLevel = 0,
    this.autoDismissSeconds,
  });

  final String id;
  final String type;
  final String roomId;
  final String actorUserId;
  final String actorName;
  final String targetUserId;
  final String targetName;
  final String message;
  final String? actorAvatarUrl;
  final int actorVipLevel;
  final int actorSendingLevel;
  final int actorReceivingLevel;
  final DateTime createdAt;
  final int? autoDismissSeconds;

  bool get isUserEntered => type == 'user_entered';
  bool get isUserRemoved => type == 'user_removed';
  bool get isRoomSystemMessage => type == 'room_system_message';
  bool get isRoomChatMessage => type == 'room_chat_message';
  bool get isChatCleared => type == 'chat_cleared';

  factory LiveRoomSystemEvent.fromJson(Map<String, dynamic> json) {
    final rawAutoDismiss = json['auto_dismiss_seconds'];
    return LiveRoomSystemEvent(
      id:
          json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      type: json['event_type']?.toString() ?? json['type']?.toString() ?? '',
      roomId: json['room_id']?.toString() ?? '',
      actorUserId: json['actor_user_id']?.toString() ?? '',
      actorName: json['actor_name']?.toString() ?? '',
      targetUserId: json['target_user_id']?.toString() ?? '',
      targetName: json['target_name']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      actorAvatarUrl: _text(json['actor_avatar_url'] ?? json['actorAvatarUrl']),
      actorVipLevel: _int(json['actor_vip_level'] ?? json['actorVipLevel']),
      actorSendingLevel: _int(
        json['actor_sending_level'] ?? json['actorSendingLevel'],
      ),
      actorReceivingLevel: _int(
        json['actor_receiving_level'] ?? json['actorReceivingLevel'],
      ),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      autoDismissSeconds: rawAutoDismiss == null
          ? null
          : int.tryParse(rawAutoDismiss.toString()),
    );
  }
}

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty || text == 'null' ? null : text;
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
