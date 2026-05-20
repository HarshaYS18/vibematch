import 'package:flutter/material.dart';

import '../../controllers/inbox_call_controller.dart';
import '../../models/inbox_call_models.dart';
import '../../models/inbox_models.dart';
import '../pages/inbox_active_call_page.dart';

class InboxCallActionSheet extends StatefulWidget {
  const InboxCallActionSheet({
    super.key,
    required this.conversation,
    required this.callController,
  });

  final InboxConversation conversation;
  final InboxCallController callController;

  @override
  State<InboxCallActionSheet> createState() => _InboxCallActionSheetState();
}

class _InboxCallActionSheetState extends State<InboxCallActionSheet> {
  static const _ink = Color(0xFF111114);
  static const _muted = Color(0xFF71717A);
  static const _line = Color(0xFFEDEDEF);
  static const _blue = Color(0xFF3797F0);
  static const _red = Color(0xFFEF4444);

  bool _busy = false;

  Future<void> _startCall(InboxCallType type) async {
    if (_busy) return;
    if (widget.conversation.isOfficial) {
      _toast('Official team chats cannot be called.');
      return;
    }

    final existingCall = widget.callController.activeCall;
    if (existingCall != null && !existingCall.isTerminal) {
      _toast('End the current call before starting another one.');
      return;
    }

    setState(() => _busy = true);
    final session = await widget.callController.startCall(
      conversation: widget.conversation,
      callType: type,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (session == null) {
      _toast(widget.callController.errorMessage ?? 'Could not start call.');
      return;
    }

    final navigator = Navigator.of(context);
    navigator.pop();
    await navigator.push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => InboxActiveCallPage(
          callController: widget.callController,
          initialSession: session,
        ),
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _ink,
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final callDisabled = widget.conversation.isOfficial;
    final existingCall = widget.callController.activeCall;
    final callInProgress = existingCall != null && !existingCall.isTerminal;
    final disabled = callDisabled || callInProgress;
    final avatarUrl = widget.conversation.avatarUrl?.trim();

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: EdgeInsets.fromLTRB(18, 10, 18, 16 + bottom),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(color: const Color(0xFFD4D4D8), borderRadius: BorderRadius.circular(99)),
            ),
            const SizedBox(height: 18),
            CircleAvatar(
              radius: 34,
              backgroundColor: const Color(0xFFF1F1F3),
              backgroundImage: avatarUrl == null || avatarUrl.isEmpty ? null : NetworkImage(avatarUrl),
              child: avatarUrl == null || avatarUrl.isEmpty
                  ? Text(
                      widget.conversation.avatarText,
                      style: const TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w800),
                    )
                  : null,
            ),
            const SizedBox(height: 10),
            Text(
              widget.conversation.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _ink, fontSize: 18.5, fontWeight: FontWeight.w800, letterSpacing: -0.2),
            ),
            const SizedBox(height: 3),
            Text(
              callDisabled
                  ? 'Calls are not available for official chats.'
                  : callInProgress
                      ? 'A call is already active.'
                      : widget.conversation.isOnline
                          ? 'online'
                          : widget.conversation.safePresenceText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: disabled ? _red : _muted,
                fontSize: 12.2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _CallActionButton(
                  icon: Icons.call_rounded,
                  title: 'Voice',
                  busy: _busy || disabled,
                  color: _blue,
                  onTap: () => _startCall(InboxCallType.audio),
                ),
                const SizedBox(width: 34),
                _CallActionButton(
                  icon: Icons.videocam_rounded,
                  title: 'Video',
                  busy: _busy || disabled,
                  color: _ink,
                  onTap: () => _startCall(InboxCallType.video),
                ),
              ],
            ),
            if (disabled) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFCDD2)),
                ),
                child: Text(
                  callDisabled ? 'Official team chats use support messages.' : 'End your active call first.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _red, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  const _CallActionButton({
    required this.icon,
    required this.title,
    required this.busy,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool busy;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: busy ? 0.45 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 25),
            ),
            const SizedBox(height: 9),
            Text(title, style: const TextStyle(color: _InboxCallActionSheetState._ink, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
