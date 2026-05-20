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
  }

  @override
  void dispose() {
    widget.callController.removeListener(_handleCallChanged);
    super.dispose();
  }

  void _handleCallChanged() {
    final session = widget.callController.activeCall;
    if (!mounted || session == null) return;
    if (_shownCallId == session.id) return;
    if (session.isIncoming && session.isRinging) {
      _shownCallId = session.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showIncomingCall(session);
      });
    }
  }

  Future<void> _showIncomingCall(InboxCallSession initialSession) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AnimatedBuilder(
        animation: widget.callController,
        builder: (context, _) {
          final session = widget.callController.activeCall ?? initialSession;
          return InboxCallOverlaySheet(
            session: session,
            onAccept: widget.callController.acceptActiveCall,
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
