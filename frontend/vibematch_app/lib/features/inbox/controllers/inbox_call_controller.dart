import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/inbox_call_api_service.dart';
import '../models/inbox_call_models.dart';
import '../models/inbox_models.dart';

class InboxCallController extends ChangeNotifier {
  InboxCallController({InboxCallApiService? apiService})
    : _apiService = apiService ?? const InboxCallApiService();

  final InboxCallApiService _apiService;
  static const Duration incomingRingTimeout = Duration(seconds: 45);

  InboxCallSession? _activeCall;
  InboxCallSummaryMessage? _lastSummary;
  Timer? _missedCallTimer;
  bool _busy = false;
  String? _errorMessage;

  InboxCallSession? get activeCall => _activeCall;
  InboxCallSummaryMessage? get lastSummary => _lastSummary;
  bool get hasActiveCall => _activeCall != null;
  bool get busy => _busy;
  String? get errorMessage => _errorMessage;

  InboxCallSession? activeCallForConversation(String conversationId) {
    final session = _activeCall;
    if (session == null || session.conversationId != conversationId) return null;
    return session;
  }

  Future<InboxCallSession?> startCall({
    required InboxConversation conversation,
    required InboxCallType callType,
  }) async {
    if (_busy) return _activeCall;
    _setBusy(true);
    try {
      final session = await _apiService.startCall(
        conversationId: conversation.id,
        callType: callType,
        peerName: conversation.title,
        peerAvatarText: conversation.avatarText,
      );
      _activeCall = session;
      _lastSummary = null;
      _errorMessage = null;
      _cancelMissedCallTimer();
      notifyListeners();
      return session;
    } catch (error) {
      _errorMessage = error.toString();
      notifyListeners();
      return null;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> acceptActiveCall() async {
    final session = _activeCall;
    if (session == null || _busy) return;
    _setBusy(true);
    try {
      _activeCall = await _apiService.acceptCall(session: session);
      _lastSummary = null;
      _errorMessage = null;
      _cancelMissedCallTimer();
      notifyListeners();
    } catch (error) {
      _errorMessage = error.toString();
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> declineActiveCall({String? reason}) async {
    final session = _activeCall;
    if (session == null || _busy) return;
    _setBusy(true);
    try {
      final ended = await _apiService.declineCall(
        session: session,
        reason: reason ?? 'declined',
      );
      _lastSummary = _summaryFromSession(ended);
      _activeCall = null;
      _errorMessage = null;
      _cancelMissedCallTimer();
      notifyListeners();
    } catch (error) {
      _errorMessage = error.toString();
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> endActiveCall({String? reason}) async {
    final session = _activeCall;
    if (session == null || _busy) return;
    _setBusy(true);
    try {
      final ended = await _apiService.endCall(
        session: session,
        reason: reason ?? 'ended',
      );
      _lastSummary = _summaryFromSession(ended);
      _activeCall = null;
      _errorMessage = null;
      _cancelMissedCallTimer();
      notifyListeners();
    } catch (error) {
      _errorMessage = error.toString();
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  void clearCall() {
    _activeCall = null;
    _errorMessage = null;
    _cancelMissedCallTimer();
    notifyListeners();
  }

  void clearLastSummary() {
    _lastSummary = null;
    notifyListeners();
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
        _activeCall = _apiService.callFromRealtimeJson(
          rawCall,
          peerName: conversation.title,
          peerAvatarText: conversation.avatarText,
          direction: direction,
        );
        _lastSummary = null;
        _errorMessage = null;
        _scheduleMissedCallTimer(_activeCall);
        notifyListeners();
        break;
      case 'inbox_call_accepted':
        _activeCall = _apiService.callFromRealtimeJson(
          rawCall,
          peerName: conversation.title,
          peerAvatarText: conversation.avatarText,
          direction: _activeCall?.direction ?? direction,
        );
        _lastSummary = null;
        _errorMessage = null;
        _cancelMissedCallTimer();
        notifyListeners();
        break;
      case 'inbox_call_declined':
      case 'inbox_call_ended':
      case 'inbox_call_missed':
        final session = _apiService.callFromRealtimeJson(
          rawCall,
          peerName: conversation.title,
          peerAvatarText: conversation.avatarText,
          direction: _activeCall?.direction ?? direction,
        );
        _lastSummary = _summaryFromSession(session);
        _activeCall = null;
        _errorMessage = null;
        _cancelMissedCallTimer();
        notifyListeners();
        break;
      default:
        break;
    }
  }

  InboxCallSummaryMessage? summaryFromActiveCall({required InboxCallStatus status}) {
    final session = _activeCall;
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
      final current = _activeCall;
      if (current == null || current.id != session.id || !current.isIncoming || !current.isRinging) {
        return;
      }
      try {
        final ended = await _apiService.timeoutRingingCall(session: current);
        _lastSummary = _summaryFromSession(ended);
      } catch (error) {
        _errorMessage = error.toString();
        _lastSummary = summaryFromActiveCall(status: InboxCallStatus.missed);
      } finally {
        _activeCall = null;
        _cancelMissedCallTimer();
        notifyListeners();
      }
    });
  }

  void _cancelMissedCallTimer() {
    _missedCallTimer?.cancel();
    _missedCallTimer = null;
  }

  @override
  void dispose() {
    _cancelMissedCallTimer();
    super.dispose();
  }

  void _setBusy(bool value) {
    if (_busy == value) return;
    _busy = value;
    notifyListeners();
  }
}
