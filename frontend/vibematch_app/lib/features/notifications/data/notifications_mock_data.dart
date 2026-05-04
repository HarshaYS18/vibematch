import '../models/notification_item.dart';
import '../models/notification_type.dart';

class NotificationsMockData {
  const NotificationsMockData._();

  static const List<NotificationItem> items = [
    NotificationItem(
      id: 'n1',
      type: NotificationType.allVibeMention,
      senderName: 'Founder',
      targetName: 'All fans',
      title: '@all mentioned in a Vibe',
      body: 'Founder tagged all fans in a new Vibe update.',
      vibeTitle: 'Building Vibe Match Vibes',
      timeAgo: '2m',
      isUnread: true,
    ),
    NotificationItem(
      id: 'n2',
      type: NotificationType.targetedVibeMention,
      senderName: 'Riya',
      targetName: 'Harsha',
      title: '@Harsha mentioned in a Vibe',
      body: 'Riya mentioned you in her new Vibe post.',
      vibeTitle: 'Late Night Chill was crazy today',
      timeAgo: '18m',
      isUnread: true,
    ),
    NotificationItem(
      id: 'n3',
      type: NotificationType.targetedCommentMention,
      senderName: 'Meera',
      targetName: 'Harsha',
      title: '@Harsha mentioned in a comment',
      body: 'Meera mentioned you in a Vibe comment.',
      vibeTitle: 'Premium profile design idea',
      timeAgo: '41m',
      isUnread: false,
    ),
    NotificationItem(
      id: 'n4',
      type: NotificationType.targetedVibeMention,
      senderName: 'Akhil',
      targetName: 'Riya',
      title: '@Riya mentioned in a Vibe',
      body: 'Akhil mentioned Riya in a video Vibe.',
      vibeTitle: 'Telugu music room highlights',
      timeAgo: '1h',
      isUnread: false,
    ),
    NotificationItem(
      id: 'n5',
      type: NotificationType.allVibeMention,
      senderName: 'Vibe Match Team',
      targetName: 'All fans',
      title: '@all mentioned in an official Vibe',
      body: 'Vibe Match Team tagged all followers about a new event.',
      vibeTitle: 'Official weekend event is live',
      timeAgo: '3h',
      isUnread: false,
    ),
  ];
}
