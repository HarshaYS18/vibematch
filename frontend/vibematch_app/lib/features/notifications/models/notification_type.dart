enum NotificationType {
  allVibeMention,
  targetedVibeMention,
  targetedCommentMention,
}

extension NotificationTypeLabel on NotificationType {
  String get label {
    switch (this) {
      case NotificationType.allVibeMention:
        return '@all Vibe';
      case NotificationType.targetedVibeMention:
        return '@mention Vibe';
      case NotificationType.targetedCommentMention:
        return '@mention Comment';
    }
  }
}
