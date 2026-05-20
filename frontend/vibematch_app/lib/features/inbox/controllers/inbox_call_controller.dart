import 'package:flutter/foundation.dart';

import '../data/inbox_call_api_service.dart';
import '../models/inbox_call_models.dart';
import '../models/inbox_models.dart';

class InboxCallController extends ChangeNotifier {
  InboxCallController({InboxCallApiService? apiService}) : _apiService = apiService ?? const InboxCallApiService();

  final InboxCallApiService _apiService;
  InboxCallSession? _activeCall;
  bool _busy = false;
  String? _errorMessage;

  InboxCallSession? get activeCall => _activeCall;
  bool get hasActiveCall => _activeCall != null;
  bool get busy => _busy;
  String? get errorMessage => _errorMessage;

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
      _errorMessage = null;
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
      _errorMessage = null;
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
      await _apiService.declineCall(session: session, reason: reason ?? 'declined');
      _activeCall = null;
      _errorMessage = null;
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
      await _apiService.endCall(session: session, reason: reason ?? 'ended');
      _activeCall = null;
      _errorMessage = null;
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
    notifyListeners();
  }

  void handleRealtimeEvent({
    required Map<String, dynamic> event,
    required InboxConversation conversation,
  }) {
    final eventName = event['event']?.toString();
    final rawCall = event['call'];
    if (rawCall is! Map<String, dynamic>) return;

    switch (eventName) {
      case 'inbox_call_started':
        _activeCall = _apiService.callFromRealtimeJson(
          rawCall,
          peerName: conversation.title,
          peerAvatarText: conversation.avatarText,
          direction: InboxCallDirection.incoming,
        );
        _errorMessage = null;
        notifyListeners();
        break;
      case 'inbox_call_accepted':
        _activeCall = _apiService.callFromRealtimeJson(
          rawCall,
          peerName: conversation.title,
          peerAvatarText: conversation.avatarText,
          direction: _activeCall?.direction ?? InboxCallDirection.outgoing,
        );
        _errorMessage = null;
        notifyListeners();
        break;
      case 'inbox_call_declined':
      case 'inbox_call_ended':
      case 'inbox_call_missed':
        _activeCall = null;
        _errorMessage = null;
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

  void _setBusy(bool value) {
    if (_busy == value) return;
    _busy = value;
    notifyListeners();
  }
}
