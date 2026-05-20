import 'package:flutter/material.dart';

import '../../controllers/inbox_call_controller.dart';
import '../../models/inbox_call_models.dart';

class InboxActiveCallPage extends StatelessWidget {
  const InboxActiveCallPage({
    super.key,
    required this.callController,
    required this.initialSession,
  });

  final InboxCallController callController;
  final InboxCallSession initialSession;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: callController,
      builder: (context, _) {
        final session = callController.activeCall ?? initialSession;
        final connected = session.isConnected;
        final colors = session.isVideo
            ? const [Color(0xFF6D5DF6), Color(0xFFFF4F9A)]
            : const [Color(0xFF12C7B7), Color(0xFF6D5DF6)];

        return Scaffold(
          backgroundColor: const Color(0xFF080512),
          body: SafeArea(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.12,
                  colors: [colors.first.withValues(alpha: 0.28), const Color(0xFF080512)],
                ),
              ),
              child: Column(
                children: [
                  _CallTopBar(session: session),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 136,
                          height: 136,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: colors),
                            boxShadow: [
                              BoxShadow(
                                color: colors.last.withValues(alpha: 0.32),
                                blurRadius: 42,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF1A102A),
                            ),
                            child: Center(
                              child: Text(
                                session.peerAvatarText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 42,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          session.peerName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          connected ? 'Connected' : session.statusLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF2DD4BF),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 28),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                          ),
                          child: Text(
                            session.roomId == null
                                ? 'Signaling ready. Media room will attach when WebRTC/mediasoup gateway is connected.'
                                : 'Media room: ${session.roomId}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFCDBCE7),
                              fontSize: 12,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _CallControls(
                    session: session,
                    onEnd: () async {
                      await callController.endActiveCall(reason: 'ended');
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CallTopBar extends StatelessWidget {
  const _CallTopBar({required this.session});

  final InboxCallSession session;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 14, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 26),
          ),
          Expanded(
            child: Text(
              session.isVideo ? 'Video call' : 'Voice call',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Text(
              session.iconLabel,
              style: const TextStyle(color: Color(0xFFCDBCE7), fontSize: 10.5, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _CallControls extends StatefulWidget {
  const _CallControls({required this.session, required this.onEnd});

  final InboxCallSession session;
  final Future<void> Function() onEnd;

  @override
  State<_CallControls> createState() => _CallControlsState();
}

class _CallControlsState extends State<_CallControls> {
  bool _muted = false;
  bool _speaker = true;
  bool _camera = true;
  bool _ending = false;

  Future<void> _end() async {
    if (_ending) return;
    setState(() => _ending = true);
    await widget.onEnd();
    if (mounted) setState(() => _ending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 10, 18, 20 + MediaQuery.paddingOf(context).bottom),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlButton(
            icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: _muted ? 'Muted' : 'Mute',
            active: _muted,
            onTap: () => setState(() => _muted = !_muted),
          ),
          _ControlButton(
            icon: _speaker ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            label: 'Speaker',
            active: _speaker,
            onTap: () => setState(() => _speaker = !_speaker),
          ),
          if (widget.session.isVideo)
            _ControlButton(
              icon: _camera ? Icons.videocam_rounded : Icons.videocam_off_rounded,
              label: 'Camera',
              active: _camera,
              onTap: () => setState(() => _camera = !_camera),
            ),
          _ControlButton(
            icon: _ending ? Icons.hourglass_top_rounded : Icons.call_end_rounded,
            label: 'End',
            danger: true,
            onTap: _end,
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? const Color(0xFFE84C72)
        : active
            ? const Color(0xFF12C7B7)
            : Colors.white.withValues(alpha: 0.12);
    final iconColor = danger || active ? Colors.white : const Color(0xFFCDBCE7);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 23),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Color(0xFFCDBCE7), fontSize: 11, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
