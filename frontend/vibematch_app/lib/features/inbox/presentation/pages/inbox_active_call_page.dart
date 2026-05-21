import 'package:flutter/material.dart';

import '../../controllers/inbox_call_controller.dart';
import '../../data/inbox_call_media_bridge.dart';
import '../../models/inbox_call_models.dart';

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
  static const _bg = Color(0xFF07070A);
  static const _ink = Colors.white;
  static const _muted = Color(0xFFB8B8C2);
  static const _blue = Color(0xFF3797F0);
  static const _green = Color(0xFF22C55E);
  static const _red = Color(0xFFEF4444);

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
      if (active.isConnected) _maybeJoinMedia();
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
      setState(() => _mediaError = 'Could not connect call. Try again.');
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _mediaReady = false;
        _mediaJoining = false;
        _mediaError = 'Could not connect call. Try again.';
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

  String _callStateLabel(InboxCallSession session) {
    if (_mediaError != null) return _mediaError!;
    if (session.isConnected) {
      if (_mediaJoining) return 'Connecting...';
      if (_mediaReady) return 'Connected';
      return 'Connecting...';
    }
    final label = session.statusLabel.trim();
    if (label.toLowerCase().contains('ring')) return 'Ringing...';
    if (label.toLowerCase().contains('connect')) return 'Connecting...';
    return label.isEmpty ? 'Calling...' : label;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.callController,
      builder: (context, _) {
        final session =
            widget.callController.activeCall ?? widget.initialSession;
        return Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(child: _CallBackdrop(session: session)),
                Column(
                  children: [
                    _CallTopBar(session: session),
                    Expanded(
                      child: session.isVideo
                          ? _VideoCallBody(
                              session: session,
                              stateLabel: _callStateLabel(session),
                              mediaError: _mediaError,
                              onRetry: _maybeJoinMedia,
                            )
                          : _VoiceCallBody(
                              session: session,
                              stateLabel: _callStateLabel(session),
                              mediaError: _mediaError,
                              mediaJoining: _mediaJoining,
                              onRetry: _maybeJoinMedia,
                            ),
                    ),
                    _CallControls(
                      session: session,
                      onMuteChanged: _setMuted,
                      onEnd: _endCall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CallBackdrop extends StatelessWidget {
  const _CallBackdrop({required this.session});

  final InboxCallSession session;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.18,
          colors: session.isVideo
              ? const [Color(0xFF26262C), Color(0xFF111114), Color(0xFF07070A)]
              : const [Color(0xFF172033), Color(0xFF101014), Color(0xFF07070A)],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _CallTopBar extends StatelessWidget {
  const _CallTopBar({required this.session});

  final InboxCallSession session;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          Expanded(
            child: Text(
              session.isVideo ? 'Video call' : 'Voice call',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _VoiceCallBody extends StatelessWidget {
  const _VoiceCallBody({
    required this.session,
    required this.stateLabel,
    required this.mediaError,
    required this.mediaJoining,
    required this.onRetry,
  });

  final InboxCallSession session;
  final String stateLabel;
  final String? mediaError;
  final bool mediaJoining;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RingingAvatar(
              session: session,
              active: !session.isConnected || mediaJoining,
            ),
            const SizedBox(height: 26),
            Text(
              session.peerName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _InboxActiveCallPageState._ink,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            _StateText(
              label: stateLabel,
              error: mediaError != null,
              onRetry: mediaError == null ? null : onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _RingingAvatar extends StatefulWidget {
  const _RingingAvatar({required this.session, required this.active});

  final InboxCallSession session;
  final bool active;

  @override
  State<_RingingAvatar> createState() => _RingingAvatarState();
}

class _RingingAvatarState extends State<_RingingAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    if (widget.active) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _RingingAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = widget.active ? _controller.value : 0.0;
        return Container(
          width: 148 + (value * 18),
          height: 148 + (value * 18),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(
              0xFF3797F0,
            ).withValues(alpha: 0.06 + value * 0.05),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF3797F0,
                ).withValues(alpha: 0.18 + value * 0.12),
                blurRadius: 36 + value * 18,
                spreadRadius: 4 + value * 7,
              ),
            ],
          ),
          child: Center(child: child),
        );
      },
      child: CircleAvatar(
        radius: 64,
        backgroundColor: Colors.white.withValues(alpha: 0.12),
        child: Text(
          widget.session.peerAvatarText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 42,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _VideoCallBody extends StatelessWidget {
  const _VideoCallBody({
    required this.session,
    required this.stateLabel,
    required this.mediaError,
    required this.onRetry,
  });

  final InboxCallSession session;
  final String stateLabel;
  final String? mediaError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            decoration: BoxDecoration(
              color: const Color(0xFF111114),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  child: Text(
                    session.peerAvatarText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  session.peerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                _StateText(
                  label: stateLabel,
                  error: mediaError != null,
                  onRetry: mediaError == null ? null : onRetry,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 24,
          top: 24,
          child: Container(
            width: 108,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.person_rounded,
                color: Colors.white70,
                size: 34,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StateText extends StatelessWidget {
  const _StateText({
    required this.label,
    required this.error,
    required this.onRetry,
  });

  final String label;
  final bool error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onRetry,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: error
                ? _InboxActiveCallPageState._red.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!error)
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: _InboxActiveCallPageState._green,
                  shape: BoxShape.circle,
                ),
              )
            else
              const Icon(
                Icons.error_outline_rounded,
                color: _InboxActiveCallPageState._red,
                size: 15,
              ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: error
                      ? _InboxActiveCallPageState._red
                      : _InboxActiveCallPageState._muted,
                  fontSize: 12.5,
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
  bool _speaker = true;
  bool _camera = true;
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
    final controls = <Widget>[
      _ControlButton(
        icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
        label: _muted ? 'Muted' : 'Mute',
        active: _muted,
        onTap: _toggleMute,
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
          active: !_camera,
          onTap: () => setState(() => _camera = !_camera),
        ),
      _ControlButton(
        icon: _ending ? Icons.hourglass_top_rounded : Icons.call_end_rounded,
        label: 'End',
        danger: true,
        onTap: _end,
      ),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        10,
        18,
        20 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: controls,
        ),
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
    final background = danger
        ? _InboxActiveCallPageState._red
        : active
        ? _InboxActiveCallPageState._blue
        : Colors.white.withValues(alpha: 0.12);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: danger ? 62 : 56,
            height: danger ? 62 : 56,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: danger ? 25 : 22),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: const TextStyle(
              color: _InboxActiveCallPageState._muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
