import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/inbox_models.dart';

class InboxForegroundNotificationPayload {
  const InboxForegroundNotificationPayload({required this.conversation, required this.message});

  final InboxConversation conversation;
  final InboxMessage message;

  String get key => '${conversation.id}:${message.id ?? message.text}:${message.time}';
}

class InboxForegroundNotificationService extends ChangeNotifier {
  InboxForegroundNotificationService._();

  static final InboxForegroundNotificationService instance = InboxForegroundNotificationService._();

  InboxForegroundNotificationPayload? _payload;
  Timer? _dismissTimer;
  String? _lastShownKey;

  InboxForegroundNotificationPayload? get payload => _payload;

  void show({required InboxConversation conversation, required InboxMessage message}) {
    if (message.isMine) return;
    if (conversation.isMuted || conversation.isLockedByBackend) return;

    final next = InboxForegroundNotificationPayload(conversation: conversation, message: message);
    if (next.key == _lastShownKey) return;

    _lastShownKey = next.key;
    _payload = next;
    _dismissTimer?.cancel();
    _dismissTimer = Timer(const Duration(seconds: 4), dismiss);
    notifyListeners();
  }

  void dismiss() {
    if (_payload == null) return;
    _payload = null;
    _dismissTimer?.cancel();
    _dismissTimer = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }
}
