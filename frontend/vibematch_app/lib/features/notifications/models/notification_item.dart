import 'notification_type.dart';

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.senderName,
    required this.targetName,
    required this.title,
    required this.body,
    required this.vibeTitle,
    required this.timeAgo,
    required this.isUnread,
  });

  final String id;
  final NotificationType type;
  final String senderName;
  final String targetName;
  final String title;
  final String body;
  final String vibeTitle;
  final String timeAgo;
  final bool isUnread;
}
