import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/inbox_call_controller.dart';
import '../../models/inbox_call_models.dart';
import '../pages/inbox_active_call_page.dart';
import 'inbox_call_overlay_sheet.dart';

class InboxCallRealtimePresenter extends ConsumerStatefulWidget {
  const InboxCallRealtimePresenter({
    super.key,
    required this.callController,
    required this.child,
  });

  final InboxCallController callController;
  final Widget child;

  @override
  ConsumerState<InboxCallRealtimePresenter> createState() =>
      _InboxCallRealtimePresenterState();
}

class _InboxCallRealtimePresenterState
    extends ConsumerState<InboxCallRealtimePresenter> {
  String? _shownCallId;
  String? _lastSummaryCallId;
  bool _incomingSheetOpen = false;
  bool _activeCallPageOpen = false;

  void _handleCallChanged(InboxCallState callState) {
    if (!mounted) return;

    final session = callState.activeCall;
    if (session == null) {
      _shownCallId = null;
      _showLatestSummaryToast(callState);
      return;
    }

    if (session.isIncoming && session.isRinging) {
      if (_shownCallId == session.id || _incomingSheetOpen) return;
      _shownCallId = session.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showIncomingCall(session);
      });
      return;
    }

    if (!session.isRinging) {
      _shownCallId = null;
    }
  }

  Future<void> _showIncomingCall(InboxCallSession initialSession) async {
    if (_incomingSheetOpen) return;
    _incomingSheetOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: false,
      isDismissible: false,
      builder: (_) => Consumer(
        builder: (context, ref, child) {
          final callState = ref.watch(inboxCallControllerProvider);
          final session = callState.activeCall ?? initialSession;
          return InboxCallOverlaySheet(
            session: session,
            onAccept: () async {
              await widget.callController.acceptActiveCall();
              if (context.mounted) Navigator.pop(context);
              final active =
                  ref.read(inboxCallControllerProvider).activeCall;
              if (mounted && active != null) {
                _openActiveCallPage(active);
              }
            },
            onDecline: () async {
              await widget.callController.declineActiveCall(
                reason: 'declined',
              );
              if (context.mounted) Navigator.pop(context);
            },
            onEnd: () async {
              await widget.callController.endActiveCall(reason: 'ended');
              if (context.mounted) Navigator.pop(context);
            },
          );
        },
      ),
    );
    _incomingSheetOpen = false;
    if (mounted) {
      _showLatestSummaryToast(ref.read(inboxCallControllerProvider));
    }
  }

  Future<void> _openActiveCallPage(InboxCallSession session) async {
    if (_activeCallPageOpen || !mounted) return;
    _activeCallPageOpen = true;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => InboxActiveCallPage(
          callController: widget.callController,
          initialSession: session,
        ),
      ),
    );
    _activeCallPageOpen = false;
    if (mounted) {
      _showLatestSummaryToast(ref.read(inboxCallControllerProvider));
    }
  }

  void _showLatestSummaryToast(InboxCallState callState) {
    final summary = callState.lastSummary;
    if (summary == null || summary.callId == _lastSummaryCallId) return;
    _lastSummaryCallId = summary.callId;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF251538),
          duration: const Duration(seconds: 2),
          content: Text(
            summary.label,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<InboxCallState>(
      inboxCallControllerProvider,
      (previous, next) => _handleCallChanged(next),
    );
    final callState = ref.watch(inboxCallControllerProvider);
    final session = callState.activeCall;

    return Stack(
      children: [
        widget.child,
        if (session != null && !session.isIncoming)
          InboxMiniCallOverlay(
            session: session,
            onTap: () => _openActiveCallPage(session),
            onEnd: () =>
                widget.callController.endActiveCall(reason: 'ended'),
          ),
      ],
    );
  }
}
