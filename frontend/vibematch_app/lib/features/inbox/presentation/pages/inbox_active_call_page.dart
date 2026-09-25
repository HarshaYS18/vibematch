import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../controllers/inbox_call_controller.dart';
import '../../data/inbox_call_media_bridge.dart';
import '../../models/inbox_call_models.dart';

class InboxActiveCallPage extends ConsumerStatefulWidget {
  const InboxActiveCallPage({
    super.key,
    required this.callController,
    required this.initialSession,
  });

  final InboxCallController callController;
  final InboxCallSession initialSession;

  @override
  ConsumerState<InboxActiveCallPage> createState() => _InboxActiveCallPageState();
}

class _InboxActiveCallPageState extends ConsumerState<InboxActiveCallPage> {
  final InboxCallMediaBridge _mediaBridge = InboxCallMediaBridge();
  bool _closingFromRemote = false;
  bool _mediaJoining = false;
  bool _mediaReady = false;
  String? _mediaError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeJoinMedia());
  }

  @override
  void dispose() {
    _mediaBridge.dispose();
    super.dispose();
  }

  void _handleCallChanged(InboxCallState callState) {
    if (!mounted || _closingFromRemote) return;
    final active = callState.activeCall;
    if (active != null && active.id == widget.initialSession.id && !active.isTerminal) {
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
    final session = ref.read(inboxCallControllerProvider).activeCall ?? widget.initialSession;
    if (!mounted || _mediaJoining || _mediaReady || !session.isConnected) return;
    final roomId = session.roomId;
    if (roomId == null || roomId.trim().isEmpty) {
      setState(() => _mediaError = 'Call media is not ready.');
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
        _mediaError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _endCall() async {
    await _mediaBridge.leave();
    await widget.callController.endActiveCall(reason: 'ended');
    if (mounted) Navigator.pop(context);
  }

  Future<void> _setMuted(bool muted) async => _mediaBridge.setMuted(muted);
  Future<void> _setCameraEnabled(bool enabled) async => _mediaBridge.setCameraEnabled(enabled);
  Future<void> _switchCamera() async => _mediaBridge.switchCamera();

  @override
  Widget build(BuildContext context) {
    ref.listen<InboxCallState>(
      inboxCallControllerProvider,
      (previous, next) => _handleCallChanged(next),
    );
    final callState = ref.watch(inboxCallControllerProvider);
    final session = callState.activeCall ?? widget.initialSession;
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
                gradient: RadialGradient(center: Alignment.topCenter, radius: 1.12, colors: [colors.first.withValues(alpha: 0.28), const Color(0xFF080512)]),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: session.isVideo
                        ? _VideoCallStage(
                            mediaBridge: _mediaBridge,
                            session: session,
                            mediaReady: _mediaReady,
                            colors: colors,
                          )
                        : _VoiceCallStage(session: session, colors: colors, mediaJoining: _mediaJoining, mediaReady: _mediaReady, mediaError: _mediaError, onRetry: _maybeJoinMedia),
                  ),
                  Positioned(top: 0, left: 0, right: 0, child: _CallTopBar(session: session)),
                  if (session.isVideo)
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 98 + MediaQuery.paddingOf(context).bottom,
                      child: _MediaStatusPill(session: session, mediaJoining: _mediaJoining, mediaReady: _mediaReady, mediaError: _mediaError, onRetry: _maybeJoinMedia, compact: true),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _CallControls(
                      session: session,
                      onMuteChanged: _setMuted,
                      onCameraChanged: _setCameraEnabled,
                      onSwitchCamera: _switchCamera,
                      onEnd: _endCall,
                    ),
                  ),
                  if (!connected)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: Container(
                            margin: const EdgeInsets.only(top: 220),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(999)),
                            child: Text(session.statusLabel, style: const TextStyle(color: Color(0xFFCDBCE7), fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
  }
}

class _VideoCallStage extends StatelessWidget {
  const _VideoCallStage({required this.mediaBridge, required this.session, required this.mediaReady, required this.colors});
  final InboxCallMediaBridge mediaBridge;
  final InboxCallSession session;
  final bool mediaReady;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<InboxRemoteVideoStream>>(
      valueListenable: mediaBridge.remoteVideoStreams,
      builder: (context, remotes, _) {
        final remote = remotes.isNotEmpty ? remotes.first : null;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (remote != null)
              _WebRtcVideoView(stream: remote.stream, mirror: false, fit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
            else
              _VideoWaitingBackground(session: session, colors: colors, mediaReady: mediaReady),
            Positioned(
              right: 14,
              top: 64,
              child: ValueListenableBuilder<MediaStream?>(
                valueListenable: mediaBridge.localVideoStream,
                builder: (context, localStream, _) {
                  if (localStream == null) return const SizedBox.shrink();
                  return _LocalPreview(stream: localStream);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _VideoWaitingBackground extends StatelessWidget {
  const _VideoWaitingBackground({required this.session, required this.colors, required this.mediaReady});
  final InboxCallSession session;
  final List<Color> colors;
  final bool mediaReady;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 124,
            height: 124,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: colors), boxShadow: [BoxShadow(color: colors.last.withValues(alpha: 0.28), blurRadius: 34)]),
            child: Container(
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF1A102A)),
              child: Center(child: Text(session.peerAvatarText, style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w700))),
            ),
          ),
          const SizedBox(height: 14),
          Text(session.peerName, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          const SizedBox(height: 6),
          Text(mediaReady ? 'Waiting for video...' : 'Preparing video...', style: const TextStyle(color: Color(0xFFCDBCE7), fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _LocalPreview extends StatelessWidget {
  const _LocalPreview({required this.stream});
  final MediaStream stream;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 146,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withValues(alpha: 0.24), width: 1), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.24), blurRadius: 20, offset: const Offset(0, 10))]),
      child: _WebRtcVideoView(stream: stream, mirror: true, fit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
    );
  }
}

class _WebRtcVideoView extends StatefulWidget {
  const _WebRtcVideoView({required this.stream, required this.mirror, required this.fit});
  final MediaStream stream;
  final bool mirror;
  final RTCVideoViewObjectFit fit;

  @override
  State<_WebRtcVideoView> createState() => _WebRtcVideoViewState();
}

class _WebRtcVideoViewState extends State<_WebRtcVideoView> {
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  MediaStream? _attachedStream;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant _WebRtcVideoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream.id != widget.stream.id) _attach(widget.stream);
  }

  Future<void> _init() async {
    await _renderer.initialize();
    if (!mounted) return;
    _attach(widget.stream);
  }

  void _attach(MediaStream stream) {
    _attachedStream = stream;
    _renderer.srcObject = stream;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _renderer.srcObject = null;
    _renderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_attachedStream == null) return const ColoredBox(color: Colors.black);
    return RTCVideoView(_renderer, mirror: widget.mirror, objectFit: widget.fit);
  }
}

class _VoiceCallStage extends StatelessWidget {
  const _VoiceCallStage({required this.session, required this.colors, required this.mediaJoining, required this.mediaReady, required this.mediaError, required this.onRetry});
  final InboxCallSession session;
  final List<Color> colors;
  final bool mediaJoining;
  final bool mediaReady;
  final String? mediaError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 66),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 128,
                height: 128,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: colors), boxShadow: [BoxShadow(color: colors.last.withValues(alpha: 0.30), blurRadius: 38, spreadRadius: 3)]),
                child: Container(decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF1A102A)), child: Center(child: Text(session.peerAvatarText, style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w700))))
              ),
              const SizedBox(height: 20),
              Text(session.peerName, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
              const SizedBox(height: 8),
              Text(session.isConnected ? 'Connected' : session.statusLabel, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF2DD4BF), fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              _MediaStatusPill(session: session, mediaJoining: mediaJoining, mediaReady: mediaReady, mediaError: mediaError, onRetry: onRetry),
            ],
          ),
        ),
        const SizedBox(height: 102),
      ],
    );
  }
}

class _MediaStatusPill extends StatelessWidget {
  const _MediaStatusPill({required this.session, required this.mediaJoining, required this.mediaReady, required this.mediaError, required this.onRetry, this.compact = false});
  final InboxCallSession session;
  final bool mediaJoining;
  final bool mediaReady;
  final String? mediaError;
  final VoidCallback onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final error = mediaError;
    final mediaName = session.isVideo ? 'video' : 'audio';
    final label = error != null
        ? 'Connection failed. Tap to retry.'
        : mediaReady
            ? '${mediaName[0].toUpperCase()}${mediaName.substring(1)} connected'
            : mediaJoining
                ? 'Connecting $mediaName...'
                : session.isConnected
                    ? 'Preparing $mediaName...'
                    : 'Waiting for answer';

    return InkWell(
      onTap: error == null ? null : onRetry,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: compact ? 0 : 28),
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: compact ? 7 : 9),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(999), border: Border.all(color: error == null ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFE84C72).withValues(alpha: 0.55))),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (mediaJoining)
              const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2DD4BF)))
            else
              Icon(error == null ? mediaReady ? Icons.graphic_eq_rounded : Icons.wifi_tethering_rounded : Icons.error_outline_rounded, color: error == null ? const Color(0xFF2DD4BF) : const Color(0xFFE84C72), size: 15),
            const SizedBox(width: 7),
            Flexible(child: Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFCDBCE7), fontSize: 10.8, height: 1.1, fontWeight: FontWeight.w600))),
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
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 24)),
          Expanded(child: Text(session.isVideo ? 'Video call' : 'Voice call', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withValues(alpha: 0.10))),
            child: Text(session.iconLabel, style: const TextStyle(color: Color(0xFFCDBCE7), fontSize: 9.8, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _CallControls extends StatefulWidget {
  const _CallControls({required this.session, required this.onMuteChanged, required this.onCameraChanged, required this.onSwitchCamera, required this.onEnd});
  final InboxCallSession session;
  final Future<void> Function(bool muted) onMuteChanged;
  final Future<void> Function(bool enabled) onCameraChanged;
  final Future<void> Function() onSwitchCamera;
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

  Future<void> _toggleCamera() async {
    final next = !_camera;
    setState(() => _camera = next);
    await widget.onCameraChanged(next);
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
      padding: EdgeInsets.fromLTRB(14, 10, 14, 18 + MediaQuery.paddingOf(context).bottom),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlButton(icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded, label: _muted ? 'Muted' : 'Mute', active: _muted, onTap: _toggleMute),
          _ControlButton(icon: _speaker ? Icons.volume_up_rounded : Icons.volume_off_rounded, label: 'Speaker', active: _speaker, onTap: () => setState(() => _speaker = !_speaker)),
          if (widget.session.isVideo) _ControlButton(icon: _camera ? Icons.videocam_rounded : Icons.videocam_off_rounded, label: 'Camera', active: !_camera, onTap: _toggleCamera),
          if (widget.session.isVideo) _ControlButton(icon: Icons.cameraswitch_rounded, label: 'Flip', onTap: widget.onSwitchCamera),
          _ControlButton(icon: _ending ? Icons.hourglass_top_rounded : Icons.call_end_rounded, label: 'End', danger: true, onTap: _end),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({required this.icon, required this.label, required this.onTap, this.active = false, this.danger = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFE84C72) : active ? const Color(0xFF12C7B7) : Colors.white.withValues(alpha: 0.12);
    final iconColor = danger || active ? Colors.white : const Color(0xFFCDBCE7);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 20)),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(color: Color(0xFFCDBCE7), fontSize: 9.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
