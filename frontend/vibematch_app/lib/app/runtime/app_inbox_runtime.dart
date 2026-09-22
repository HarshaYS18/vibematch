import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/inbox/controllers/inbox_controller.dart';
import '../../features/inbox/models/inbox_models.dart';

class AppInboxRuntime extends ChangeNotifier {
  AppInboxRuntime({InboxController? controller})
      : controller = controller ?? InboxController();

  final InboxController controller;

  bool _started = false;
  bool _realtimeReady = false;
  String? _lastMessageKey;
  InboxConversation? _foregroundConversation;
  InboxMessage? _foregroundMessage;
  Timer? _dismissTimer;
  String? _pendingOpenConversationId;
  int _pendingOpenRequestNonce = 0;
  String? _activeConversationId;

  InboxConversation? get foregroundConversation => _foregroundConversation;
  InboxMessage? get foregroundMessage => _foregroundMessage;
  String? get pendingOpenConversationId => _pendingOpenConversationId;
  int get pendingOpenRequestNonce => _pendingOpenRequestNonce;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    controller.addListener(_handleControllerChanged);
    await controller.loadFromBackend();
    _lastMessageKey = _latestIncomingKey();
    _realtimeReady = true;
    notifyListeners();
  }

  Future<void> ensureRealtimeConnected() {
    return controller.ensureRealtimeConnected();
  }

  void setActiveConversation(String? conversationId) {
    if (_activeConversationId == conversationId) return;
    _activeConversationId = conversationId;
    notifyListeners();
  }

  void openForegroundNotification() {
    final conversation = _foregroundConversation;
    _dismissTimer?.cancel();
    if (conversation != null) {
      _pendingOpenConversationId = conversation.id;
      _pendingOpenRequestNonce += 1;
    }
    _foregroundConversation = null;
    _foregroundMessage = null;
    notifyListeners();
  }

  void dismissForegroundNotification() {
    _dismissTimer?.cancel();
    _foregroundConversation = null;
    _foregroundMessage = null;
    notifyListeners();
  }

  String? _latestIncomingKey() {
    for (final conversation in controller.conversations) {
      if (conversation.messages.isEmpty) continue;
      final message = conversation.messages.last;
      if (message.isMine) continue;
      return _messageKey(conversation, message);
    }
    return null;
  }

  String _messageKey(
    InboxConversation conversation,
    InboxMessage message,
  ) =>
      '${conversation.id}:${message.id ?? message.text}:${message.time}';

  void _handleControllerChanged() {
    if (!_realtimeReady) {
      notifyListeners();
      return;
    }

    for (final conversation in controller.conversations) {
      if (conversation.messages.isEmpty ||
          conversation.isMuted ||
          conversation.isLockedByBackend ||
          conversation.id == _activeConversationId) {
        continue;
      }

      final message = conversation.messages.last;
      if (message.isMine) continue;
      final key = _messageKey(conversation, message);
      if (key == _lastMessageKey) continue;

      _lastMessageKey = key;
      _foregroundConversation = conversation;
      _foregroundMessage = message;
      _dismissTimer?.cancel();
      _dismissTimer = Timer(const Duration(seconds: 4), () {
        _foregroundConversation = null;
        _foregroundMessage = null;
        notifyListeners();
      });
      notifyListeners();
      return;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    controller.removeListener(_handleControllerChanged);
    controller.dispose();
    super.dispose();
  }
}

final appInboxRuntimeProvider =
    ChangeNotifierProvider.autoDispose<AppInboxRuntime>((ref) {
  return AppInboxRuntime();
});
