import 'package:flutter/material.dart';

import '../../controllers/inbox_call_controller.dart';
import '../../models/inbox_call_models.dart';
import 'inbox_call_overlay_sheet.dart';

class InboxCallRealtimePresenter extends StatefulWidget {
  const InboxCallRealtimePresenter({
    super.key,
    required this.callController,
    required this.child,
  });

  final InboxCallController callController;
  final Widget child;

  @override
  State<InboxCallRealtimePresenter> createState() => _InboxCallRealtimePresenterState();
}

class _InboxCallRealtimePresenterState extends State<InboxCallRealtimePresenter> {
  String? _shownCallId;
  String? _lastSummaryCallId;
  bool _incomingSheetOpen = false;

  @override
  void initState() {
    super.initState();
    widget.callController.addListener(_handleCallChanged);
  }

  @override
  void didUpdateWidget(covariant InboxCallRealtimePresenter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.callController == widget.callController) return;
    oldWidget.callController.removeListener(_handleCallChanged);
    widget.callController.addListener(_handleCallChanged);
    _shownCallId = null;
    _lastSummaryCallId = null;
    _incomingSheetOpen = false;
  }

  @override
  void dispose() {
    widget.callController.removeListener(_handleCallChanged);
    super.dispose();
  }

  void _handleCallChanged() {
    if (!mounted) return;

    final session = widget.callController.activeCall;
    if (session == null) {
      _shownCallId = null;
      _showLatestSummaryToast();
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
      builder: (_) => AnimatedBuilder(
        animation: widget.callController,
        builder: (context, _) {
          final session = widget.callController.activeCall ?? initialSession;
          return InboxCallOverlaySheet(
            session: session,
            onAccept: () async {
              await widget.callController.acceptActiveCall();
              if (context.mounted) Navigator.pop(context);
            },
            onDecline: () async {
              await widget.callController.declineActiveCall(reason: 'declined');
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
    if (mounted) _showLatestSummaryToast();
  }

  void _showLatestSummaryToast() {
    final summary = widget.callController.lastSummary;
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
    return AnimatedBuilder(
      animation: widget.callController,
      builder: (context, child) {
        final session = widget.callController.activeCall;
        return Stack(
          children: [
            child!,
            if (session != null && !session.isIncoming)
              InboxMiniCallOverlay(
                session: session,
                onTap: () => _showIncomingCall(session),
                onEnd: () => widget.callController.endActiveCall(reason: 'ended'),
              ),
          ],
        );
      },
      child: widget.child,
    );
  }
}
