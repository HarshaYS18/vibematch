import 'package:flutter/material.dart';

import '../../controllers/inbox_call_controller.dart';
import '../../data/inbox_call_media_bridge.dart';
import '../../models/inbox_call_models.dart';
import '../widgets/inbox_light_premium_tokens.dart';

class InboxActiveCallPage extends StatefulWidget {
  const InboxActiveCallPage({
    super.key,
    required this.callController,
    required this.initialSession,
  });

  final InboxCallController callController;
  final InboxCallSession initialSession;

  @override
  State<InboxActiveCallPage> createState() => _InboxActiveCallPageState();
}

class _InboxActiveCallPageState extends State<InboxActiveCallPage> {
  final InboxCallMediaBridge _mediaBridge = InboxCallMediaBridge();
  bool _closingFromRemote = false;
  bool _mediaJoining = false;
  bool _mediaReady = false;
  String? _mediaError;

  @override
  void initState() {
    super.initState();
    widget.callController.addListener(_handleCallChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeJoinMedia());
  }

  @override
  void dispose() {
    widget.callController.removeListener(_handleCallChanged);
    _mediaBridge.dispose();
    super.dispose();
  }

  void _handleCallChanged() {
    if (!mounted || _closingFromRemote) return;
    final active = widget.callController.activeCall;
    if (active != null &&
        active.id == widget.initialSession.id &&
        !active.isTerminal) {
      if (active.isConnected) {
        _maybeJoinMedia();
      }
      return;
    }
    _closingFromRemote = true;
    _mediaBridge.leave();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).maybePop();
    });
  }

  Future<void> _maybeJoinMedia() async {
    final session = widget.callController.activeCall ?? widget.initialSession;
    if (!mounted || _mediaJoining || _mediaReady || !session.isConnected)
      return;
    final roomId = session.roomId;
    if (roomId == null || roomId.trim().isEmpty) {
      setState(() {
        _mediaError = 'Missing audio room for this call.';
      });
      return;
    }

    setState(() {
      _mediaJoining = true;
      _mediaError = null;
    });

    try {
      await _mediaBridge.joinAndPublish(session);
      if (!mounted) return;
      setState(() {
        _mediaReady = true;
        _mediaJoining = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _mediaReady = false;
        _mediaJoining = false;
        _mediaError = error.toString();
      });
    }
  }

  Future<void> _endCall() async {
    await _mediaBridge.leave();
    await widget.callController.endActiveCall(reason: 'ended');
    if (mounted) Navigator.pop(context);
  }

  Future<void> _setMuted(bool muted) async {
    await _mediaBridge.setMuted(muted);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.callController,
      builder: (context, _) {
        final session =
            widget.callController.activeCall ?? widget.initialSession;
        final colors = session.isVideo
            ? const [
                InboxLightPremiumTokens.violetDeep,
                InboxLightPremiumTokens.pink,
              ]
            : const [
                InboxLightPremiumTokens.aqua,
                InboxLightPremiumTokens.violetDeep,
              ];

        return Scaffold(
          backgroundColor: InboxLightPremiumTokens.page,
          body: SafeArea(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.12,
                  colors: [
                    colors.first.withValues(alpha: 0.28),
                    InboxLightPremiumTokens.ink,
                  ],
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
                          _heroStatusLabel(session),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: InboxLightPremiumTokens.aqua,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _MediaStatusPill(
                          session: session,
                          mediaJoining: _mediaJoining,
                          mediaReady: _mediaReady,
                          mediaError: _mediaError,
                          onRetry: _maybeJoinMedia,
                        ),
                      ],
                    ),
                  ),
                  _CallControls(
                    session: session,
                    onMuteChanged: _setMuted,
                    onEnd: _endCall,
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

String _heroStatusLabel(InboxCallSession session) {
  if (session.isOutgoing && session.isRinging) return 'Calling...';
  if (session.isIncoming && session.isRinging) return 'Ringing...';
  if (session.isConnected) return 'Connected';
  return session.statusLabel;
}

class _MediaStatusPill extends StatelessWidget {
  const _MediaStatusPill({
    required this.session,
    required this.mediaJoining,
    required this.mediaReady,
    required this.mediaError,
    required this.onRetry,
  });

  final InboxCallSession session;
  final bool mediaJoining;
  final bool mediaReady;
  final String? mediaError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final error = mediaError;
    final label = error != null
        ? 'Audio connection failed. Tap to retry.'
        : mediaReady
        ? 'Live audio connected'
        : mediaJoining
        ? 'Joining audio...'
        : session.isConnected
        ? 'Preparing audio...'
        : 'Waiting for answer';

    return InkWell(
      onTap: error == null ? null : onRetry,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: error == null
                ? Colors.white.withValues(alpha: 0.10)
                : InboxLightPremiumTokens.danger.withValues(alpha: 0.55),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mediaJoining)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: InboxLightPremiumTokens.aqua,
                ),
              )
            else
              Icon(
                error == null
                    ? mediaReady
                          ? Icons.graphic_eq_rounded
                          : Icons.router_rounded
                    : Icons.error_outline_rounded,
                color: error == null
                    ? InboxLightPremiumTokens.aqua
                    : InboxLightPremiumTokens.danger,
                size: 16,
              ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          Expanded(
            child: Text(
              session.isVideo ? 'Video call' : 'Voice call',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
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
              style: const TextStyle(
                color: Color(0xFFCDBCE7),
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CallControls extends StatefulWidget {
  const _CallControls({
    required this.session,
    required this.onMuteChanged,
    required this.onEnd,
  });

  final InboxCallSession session;
  final Future<void> Function(bool muted) onMuteChanged;
  final Future<void> Function() onEnd;

  @override
  State<_CallControls> createState() => _CallControlsState();
}

class _CallControlsState extends State<_CallControls> {
  bool _muted = false;
  bool _ending = false;

  Future<void> _toggleMute() async {
    final next = !_muted;
    setState(() => _muted = next);
    await widget.onMuteChanged(next);
  }

  Future<void> _end() async {
    if (_ending) return;
    setState(() => _ending = true);
    await widget.onEnd();
    if (mounted) setState(() => _ending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        10,
        18,
        20 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlButton(
            icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: _muted ? 'Muted' : 'Mute',
            active: _muted,
            onTap: _toggleMute,
          ),
          _ControlButton(
            icon: _ending
                ? Icons.hourglass_top_rounded
                : Icons.call_end_rounded,
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
        ? InboxLightPremiumTokens.danger
        : active
        ? InboxLightPremiumTokens.aqua
        : Colors.white.withValues(alpha: 0.12);
    final iconColor = danger || active ? Colors.white : Color(0xFFEFE7FF);

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
            style: const TextStyle(
              color: Color(0xFFCDBCE7),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
