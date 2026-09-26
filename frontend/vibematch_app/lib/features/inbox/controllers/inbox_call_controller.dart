import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/inbox_call_api_service.dart';
import '../models/inbox_call_models.dart';
import '../models/inbox_models.dart';

const Object _inboxCallUnset = Object();

class InboxCallState {
  const InboxCallState({
    this.activeCall,
    this.lastSummary,
    this.busy = false,
    this.errorMessage,
  });

  final InboxCallSession? activeCall;
  final InboxCallSummaryMessage? lastSummary;
  final bool busy;
  final String? errorMessage;

  bool get hasActiveCall => activeCall != null;

  InboxCallState copyWith({
    Object? activeCall = _inboxCallUnset,
    Object? lastSummary = _inboxCallUnset,
    bool? busy,
    Object? errorMessage = _inboxCallUnset,
  }) {
    return InboxCallState(
      activeCall: identical(activeCall, _inboxCallUnset)
          ? this.activeCall
          : activeCall as InboxCallSession?,
      lastSummary: identical(lastSummary, _inboxCallUnset)
          ? this.lastSummary
          : lastSummary as InboxCallSummaryMessage?,
      busy: busy ?? this.busy,
      errorMessage: identical(errorMessage, _inboxCallUnset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class InboxCallController extends AutoDisposeNotifier<InboxCallState> {
  static const Duration incomingRingTimeout = Duration(seconds: 45);
  final InboxCallApiService _apiService = const InboxCallApiService();
  Timer? _missedCallTimer;

  @override
  InboxCallState build() {
    ref.onDispose(_cancelMissedCallTimer);
    return const InboxCallState();
  }

  InboxCallSession? get activeCall => state.activeCall;
  InboxCallSummaryMessage? get lastSummary => state.lastSummary;
  bool get hasActiveCall => state.hasActiveCall;
  bool get busy => state.busy;
  String? get errorMessage => state.errorMessage;

  InboxCallSession? activeCallForConversation(String conversationId) {
    final session = state.activeCall;
    if (session == null || session.conversationId != conversationId) {
      return null;
    }
    return session;
  }

  Future<InboxCallSession?> startCall({
    required InboxConversation conversation,
    required InboxCallType callType,
  }) async {
    if (state.busy) return state.activeCall;
    _setBusy(true);
    try {
      final session = await _apiService.startCall(
        conversationId: conversation.id,
        callType: callType,
        peerName: conversation.title,
        peerAvatarText: conversation.avatarText,
      );
      state = state.copyWith(
        activeCall: session,
        lastSummary: null,
        errorMessage: null,
      );
      _cancelMissedCallTimer();
      return session;
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
      return null;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> acceptActiveCall() async {
    final session = state.activeCall;
    if (session == null || state.busy) return;
    _setBusy(true);
    try {
      state = state.copyWith(
        activeCall: await _apiService.acceptCall(session: session),
        lastSummary: null,
        errorMessage: null,
      );
      _cancelMissedCallTimer();
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
    } finally {
      _setBusy(false);
    }
  }

  Future<void> declineActiveCall({String? reason}) async {
    final session = state.activeCall;
    if (session == null || state.busy) return;
    _setBusy(true);
    try {
      final ended = await _apiService.declineCall(
        session: session,
        reason: reason ?? 'declined',
      );
      state = state.copyWith(
        lastSummary: _summaryFromSession(ended),
        activeCall: null,
        errorMessage: null,
      );
      _cancelMissedCallTimer();
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
    } finally {
      _setBusy(false);
    }
  }

  Future<void> endActiveCall({String? reason}) async {
    final session = state.activeCall;
    if (session == null || state.busy) return;
    _setBusy(true);
    try {
      final ended = await _apiService.endCall(
        session: session,
        reason: reason ?? 'ended',
      );
      state = state.copyWith(
        lastSummary: _summaryFromSession(ended),
        activeCall: null,
        errorMessage: null,
      );
      _cancelMissedCallTimer();
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
    } finally {
      _setBusy(false);
    }
  }

  void clearCall() {
    state = state.copyWith(activeCall: null, errorMessage: null);
    _cancelMissedCallTimer();
  }

  void clearLastSummary() {
    state = state.copyWith(lastSummary: null);
  }

  void handleRealtimeEvent({
    required Map<String, dynamic> event,
    required InboxConversation conversation,
  }) {
    final eventName = event['event']?.toString();
    final rawCall = event['call'];
    if (rawCall is! Map<String, dynamic>) return;

    final fromSelf = event['from_self'] == true || event['is_mine'] == true;
    final direction = fromSelf
        ? InboxCallDirection.outgoing
        : InboxCallDirection.incoming;

    switch (eventName) {
      case 'inbox_call_started':
        final session = _apiService.callFromRealtimeJson(
          rawCall,
          peerName: conversation.title,
          peerAvatarText: conversation.avatarText,
          direction: direction,
        );
        state = state.copyWith(
          activeCall: session,
          lastSummary: null,
          errorMessage: null,
        );
        _scheduleMissedCallTimer(session);
        break;
      case 'inbox_call_accepted':
        state = state.copyWith(
          activeCall: _apiService.callFromRealtimeJson(
            rawCall,
            peerName: conversation.title,
            peerAvatarText: conversation.avatarText,
            direction: state.activeCall?.direction ?? direction,
          ),
          lastSummary: null,
          errorMessage: null,
        );
        _cancelMissedCallTimer();
        break;
      case 'inbox_call_declined':
      case 'inbox_call_ended':
      case 'inbox_call_missed':
        final session = _apiService.callFromRealtimeJson(
          rawCall,
          peerName: conversation.title,
          peerAvatarText: conversation.avatarText,
          direction: state.activeCall?.direction ?? direction,
        );
        state = state.copyWith(
          lastSummary: _summaryFromSession(session),
          activeCall: null,
          errorMessage: null,
        );
        _cancelMissedCallTimer();
        break;
      default:
        break;
    }
  }

  InboxCallSummaryMessage? summaryFromActiveCall({
    required InboxCallStatus status,
  }) {
    final session = state.activeCall;
    if (session == null) return null;
    return InboxCallSummaryMessage(
      callId: session.id,
      conversationId: session.conversationId,
      type: session.type,
      direction: session.direction,
      status: status,
      label: session.statusLabel,
      createdAt: DateTime.now(),
      duration: session.duration,
    );
  }

  InboxCallSummaryMessage _summaryFromSession(InboxCallSession session) {
    return InboxCallSummaryMessage(
      callId: session.id,
      conversationId: session.conversationId,
      type: session.type,
      direction: session.direction,
      status: session.status,
      label: session.statusLabel,
      createdAt: DateTime.now(),
      duration: session.duration,
    );
  }

  void _scheduleMissedCallTimer(InboxCallSession? session) {
    _cancelMissedCallTimer();
    if (session == null || !session.isIncoming || !session.isRinging) return;

    _missedCallTimer = Timer(incomingRingTimeout, () async {
      final current = state.activeCall;
      if (current == null ||
          current.id != session.id ||
          !current.isIncoming ||
          !current.isRinging) {
        return;
      }
      try {
        final ended = await _apiService.timeoutRingingCall(session: current);
        state = state.copyWith(
          lastSummary: _summaryFromSession(ended),
          activeCall: null,
          errorMessage: null,
        );
      } catch (error) {
        state = state.copyWith(
          errorMessage: error.toString(),
          lastSummary: summaryFromActiveCall(
            status: InboxCallStatus.missed,
          ),
          activeCall: null,
        );
      } finally {
        _cancelMissedCallTimer();
      }
    });
  }

  void _cancelMissedCallTimer() {
    _missedCallTimer?.cancel();
    _missedCallTimer = null;
  }

  void _setBusy(bool value) {
    if (state.busy == value) return;
    state = state.copyWith(busy: value);
  }
}

final inboxCallControllerProvider =
    NotifierProvider.autoDispose<InboxCallController, InboxCallState>(
      InboxCallController.new,
    );
