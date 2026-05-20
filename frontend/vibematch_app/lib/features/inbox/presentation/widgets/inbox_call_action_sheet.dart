import 'package:flutter/material.dart';

import '../../controllers/inbox_call_controller.dart';
import '../../models/inbox_call_models.dart';
import '../../models/inbox_models.dart';
import 'inbox_call_overlay_sheet.dart';

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
  bool _busy = false;

  Future<void> _startCall(InboxCallType type) async {
    if (_busy) return;
    if (widget.conversation.isOfficial) {
      _toast('Official team chats cannot be called.');
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
    Navigator.pop(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AnimatedBuilder(
        animation: widget.callController,
        builder: (context, _) {
          final active = widget.callController.activeCall ?? session;
          return InboxCallOverlaySheet(
            session: active,
            onAccept: widget.callController.acceptActiveCall,
            onDecline: () => widget.callController.declineActiveCall(reason: 'declined'),
            onEnd: () async {
              await widget.callController.endActiveCall(reason: 'ended');
              if (context.mounted) Navigator.pop(context);
            },
          );
        },
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF251538),
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final callDisabled = widget.conversation.isOfficial;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(14),
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0D5CB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: widget.conversation.colors),
                  ),
                  child: Center(
                    child: Text(
                      widget.conversation.avatarText,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.conversation.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF251538), fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        callDisabled
                            ? 'Official team chats use support workflows, not direct calls.'
                            : 'Start a direct Inbox call. Media routing will attach to WebRTC/mediasoup gateway.',
                        style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, height: 1.3, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _CallActionButton(
                    icon: Icons.call_rounded,
                    title: 'Voice call',
                    subtitle: callDisabled ? 'Unavailable' : 'Audio only',
                    busy: _busy || callDisabled,
                    color: const Color(0xFF12C7B7),
                    onTap: () => _startCall(InboxCallType.audio),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CallActionButton(
                    icon: Icons.videocam_rounded,
                    title: 'Video call',
                    subtitle: callDisabled ? 'Unavailable' : 'Camera call',
                    busy: _busy || callDisabled,
                    color: const Color(0xFF8C5CF6),
                    onTap: () => _startCall(InboxCallType.video),
                  ),
                ),
              ],
            ),
            if (callDisabled) ...[
              const SizedBox(height: 12),
              const Text(
                'Official team chats cannot be called.',
                style: TextStyle(color: Color(0xFFE84C72), fontSize: 11.5, fontWeight: FontWeight.w900),
              ),
            ],
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
    required this.subtitle,
    required this.busy,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool busy;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: busy ? 0.62 : 1,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Column(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 13.5, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 10.8, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
