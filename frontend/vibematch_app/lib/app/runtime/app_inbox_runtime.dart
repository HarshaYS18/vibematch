import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/inbox/controllers/inbox_controller.dart';
import '../../features/inbox/models/inbox_models.dart';
import '../../realtime/app_realtime_hub.dart';

const Object _inboxRuntimeUnset = Object();

class AppInboxRuntimeState {
  const AppInboxRuntimeState({
    this.started = false,
    this.realtimeReady = false,
    this.resyncInFlight = false,
    this.lastMessageKey,
    this.foregroundConversation,
    this.foregroundMessage,
    this.pendingOpenConversationId,
    this.pendingOpenRequestNonce = 0,
    this.activeConversationId,
  });

  final bool started;
  final bool realtimeReady;
  final bool resyncInFlight;
  final String? lastMessageKey;
  final InboxConversation? foregroundConversation;
  final InboxMessage? foregroundMessage;
  final String? pendingOpenConversationId;
  final int pendingOpenRequestNonce;
  final String? activeConversationId;

  AppInboxRuntimeState copyWith({
    bool? started,
    bool? realtimeReady,
    bool? resyncInFlight,
    Object? lastMessageKey = _inboxRuntimeUnset,
    Object? foregroundConversation = _inboxRuntimeUnset,
    Object? foregroundMessage = _inboxRuntimeUnset,
    Object? pendingOpenConversationId = _inboxRuntimeUnset,
    int? pendingOpenRequestNonce,
    Object? activeConversationId = _inboxRuntimeUnset,
  }) {
    return AppInboxRuntimeState(
      started: started ?? this.started,
      realtimeReady: realtimeReady ?? this.realtimeReady,
      resyncInFlight: resyncInFlight ?? this.resyncInFlight,
      lastMessageKey: identical(lastMessageKey, _inboxRuntimeUnset)
          ? this.lastMessageKey
          : lastMessageKey as String?,
      foregroundConversation:
          identical(foregroundConversation, _inboxRuntimeUnset)
          ? this.foregroundConversation
          : foregroundConversation as InboxConversation?,
      foregroundMessage: identical(foregroundMessage, _inboxRuntimeUnset)
          ? this.foregroundMessage
          : foregroundMessage as InboxMessage?,
      pendingOpenConversationId:
          identical(pendingOpenConversationId, _inboxRuntimeUnset)
          ? this.pendingOpenConversationId
          : pendingOpenConversationId as String?,
      pendingOpenRequestNonce:
          pendingOpenRequestNonce ?? this.pendingOpenRequestNonce,
      activeConversationId:
          identical(activeConversationId, _inboxRuntimeUnset)
          ? this.activeConversationId
          : activeConversationId as String?,
    );
  }
}

class AppInboxRuntime extends AutoDisposeNotifier<AppInboxRuntimeState> {
  late final AppRealtimeHub _realtimeHub;
  Timer? _dismissTimer;
  StreamSubscription<RealtimeResyncRequest>? _resyncSubscription;

  InboxController get controller =>
      ref.read(inboxControllerProvider.notifier);

  @override
  AppInboxRuntimeState build() {
    _realtimeHub = ref.read(appRealtimeHubProvider);
    ref.listen<InboxState>(
      inboxControllerProvider,
      (previous, next) => _handleInboxChanged(next),
    );
    ref.onDispose(() {
      _dismissTimer?.cancel();
      unawaited(_resyncSubscription?.cancel());
    });
    return const AppInboxRuntimeState();
  }

  Future<void> start() async {
    if (state.started) return;
    state = state.copyWith(started: true);
    _resyncSubscription ??= _realtimeHub.resyncRequests.listen(
      (request) => unawaited(_handleResync(request)),
    );
    await _realtimeHub.start();
    await controller.loadFromBackend();
    state = state.copyWith(
      lastMessageKey: _latestIncomingKey(
        ref.read(inboxControllerProvider).conversations,
      ),
      realtimeReady: true,
    );
  }

  Future<void> ensureRealtimeConnected() async {
    await _realtimeHub.start();
    await controller.ensureRealtimeConnected();
  }

  Future<void> _handleResync(RealtimeResyncRequest request) async {
    if (!state.started || state.resyncInFlight) return;
    if (request.stream != '*' && !request.stream.startsWith('app:')) return;

    state = state.copyWith(resyncInFlight: true);
    try {
      await controller.loadFromBackend();
      final observed = request.observedSequence;
      if (observed != null && observed > 0 && request.stream != '*') {
        _realtimeHub.markResynced(request.stream, observed);
      }
    } finally {
      state = state.copyWith(resyncInFlight: false);
    }
  }

  void setActiveConversation(String? conversationId) {
    if (state.activeConversationId == conversationId) return;
    state = state.copyWith(activeConversationId: conversationId);
  }

  void openForegroundNotification() {
    final conversation = state.foregroundConversation;
    _dismissTimer?.cancel();
    state = state.copyWith(
      pendingOpenConversationId: conversation?.id,
      pendingOpenRequestNonce: conversation == null
          ? state.pendingOpenRequestNonce
          : state.pendingOpenRequestNonce + 1,
      foregroundConversation: null,
      foregroundMessage: null,
    );
  }

  void dismissForegroundNotification() {
    _dismissTimer?.cancel();
    state = state.copyWith(
      foregroundConversation: null,
      foregroundMessage: null,
    );
  }

  String? _latestIncomingKey(List<InboxConversation> conversations) {
    for (final conversation in conversations) {
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

  void _handleInboxChanged(InboxState inbox) {
    if (!state.realtimeReady) return;

    for (final conversation in inbox.conversations) {
      if (conversation.messages.isEmpty ||
          conversation.isMuted ||
          conversation.isLockedByBackend ||
          conversation.id == state.activeConversationId) {
        continue;
      }

      final message = conversation.messages.last;
      if (message.isMine) continue;
      final key = _messageKey(conversation, message);
      if (key == state.lastMessageKey) continue;

      state = state.copyWith(
        lastMessageKey: key,
        foregroundConversation: conversation,
        foregroundMessage: message,
      );
      _dismissTimer?.cancel();
      _dismissTimer = Timer(const Duration(seconds: 4), () {
        state = state.copyWith(
          foregroundConversation: null,
          foregroundMessage: null,
        );
      });
      return;
    }
  }
}

final appInboxRuntimeProvider =
    NotifierProvider.autoDispose<AppInboxRuntime, AppInboxRuntimeState>(
      AppInboxRuntime.new,
    );
