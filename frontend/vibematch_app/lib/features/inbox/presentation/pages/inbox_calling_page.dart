import 'package:flutter/material.dart';

import '../../../../shared/communication/vm_communication_models.dart';

class InboxIncomingCallOverlay extends StatelessWidget {
  const InboxIncomingCallOverlay({
    super.key,
    required this.session,
    required this.onAccept,
    required this.onDecline,
  });

  final VmCallSessionRef session;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  VmCallParticipantRef? get _caller {
    for (final participant in session.participants) {
      if (participant.publicUserId == session.startedByPublicUserId) {
        return participant;
      }
    }
    return session.participants.isEmpty ? null : session.participants.first;
  }

  @override
  Widget build(BuildContext context) {
    final caller = _caller;
    final title = caller?.displayName ?? 'Incoming call';
    final callLabel = session.isGroup
        ? session.isVideo
            ? 'Group video call'
            : 'Group audio call'
        : session.isVideo
            ? 'Video call'
            : 'Audio call';

    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF13091F),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.26),
                blurRadius: 34,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Row(
            children: [
              _CallAvatar(participant: caller, size: 54),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      callLabel,
                      style: const TextStyle(
                        color: Color(0xFFCDBCE7),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              _RoundCallButton(
                icon: Icons.call_end_rounded,
                color: const Color(0xFFE84C72),
                onTap: onDecline,
              ),
              const SizedBox(width: 9),
              _RoundCallButton(
                icon: session.isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                color: const Color(0xFF18D17B),
                onTap: onAccept,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InboxCallingPage extends StatelessWidget {
  const InboxCallingPage({
    super.key,
    required this.session,
    required this.onEnd,
    this.onToggleMute,
    this.onToggleCamera,
    this.onSwitchCamera,
    this.onSpeaker,
    this.onMinimize,
  });

  final VmCallSessionRef session;
  final VoidCallback onEnd;
  final VoidCallback? onToggleMute;
  final VoidCallback? onToggleCamera;
  final VoidCallback? onSwitchCamera;
  final VoidCallback? onSpeaker;
  final VoidCallback? onMinimize;

  @override
  Widget build(BuildContext context) {
    final mainParticipant = session.participants.isEmpty ? null : session.participants.first;
    return Scaffold(
      backgroundColor: const Color(0xFF090314),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.2,
                    colors: [
                      const Color(0xFF7C3AED).withValues(alpha: 0.42),
                      const Color(0xFF12091F),
                      const Color(0xFF090314),
                    ],
                  ),
                ),
              ),
            ),
            if (session.isVideo)
              Positioned.fill(
                child: _VideoStage(session: session),
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CallAvatar(participant: mainParticipant, size: 118),
                    const SizedBox(height: 20),
                    Text(
                      mainParticipant?.displayName ?? 'Call',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusLabel(session.status),
                      style: const TextStyle(
                        color: Color(0xFFCDBCE7),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: _CallControlDock(
                isVideo: session.isVideo,
                onToggleMute: onToggleMute,
                onToggleCamera: onToggleCamera,
                onSwitchCamera: onSwitchCamera,
                onSpeaker: onSpeaker,
                onMinimize: onMinimize,
                onEnd: onEnd,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(VmCallStatus status) {
    return switch (status) {
      VmCallStatus.ringing => 'Ringing...',
      VmCallStatus.connecting => 'Connecting...',
      VmCallStatus.active => '00:00',
      VmCallStatus.declined => 'Declined',
      VmCallStatus.missed => 'Missed call',
      VmCallStatus.ended => 'Call ended',
      VmCallStatus.failed => 'Call failed',
      VmCallStatus.cancelled => 'Cancelled',
      VmCallStatus.idle => 'Ready',
    };
  }
}

class InboxCallSummaryPage extends StatelessWidget {
  const InboxCallSummaryPage({
    super.key,
    required this.session,
    required this.onMessage,
    required this.onCallAgain,
    required this.onBack,
    this.onVideoCall,
  });

  final VmCallSessionRef session;
  final VoidCallback onMessage;
  final VoidCallback onCallAgain;
  final VoidCallback onBack;
  final VoidCallback? onVideoCall;

  @override
  Widget build(BuildContext context) {
    final first = session.participants.isEmpty ? null : session.participants.first;
    final duration = session.durationSeconds == null ? '--:--' : _durationLabel(session.durationSeconds!);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(34),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E1230).withValues(alpha: 0.08),
                      blurRadius: 28,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _CallAvatar(participant: first, size: 92),
                    const SizedBox(height: 16),
                    Text(
                      first?.displayName ?? 'Call summary',
                      style: const TextStyle(
                        color: Color(0xFF251538),
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${session.isVideo ? 'Video' : 'Audio'} call • $duration',
                      style: const TextStyle(
                        color: Color(0xFF7B6A86),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryAction(
                            icon: Icons.message_rounded,
                            label: 'Message',
                            onTap: onMessage,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SummaryAction(
                            icon: Icons.call_rounded,
                            label: 'Call again',
                            onTap: onCallAgain,
                          ),
                        ),
                        if (onVideoCall != null) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: _SummaryAction(
                              icon: Icons.videocam_rounded,
                              label: 'Video',
                              onTap: onVideoCall!,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  String _durationLabel(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

class _VideoStage extends StatelessWidget {
  const _VideoStage({required this.session});

  final VmCallSessionRef session;

  @override
  Widget build(BuildContext context) {
    final participants = session.participants.take(4).toList();
    if (participants.isEmpty) {
      return const Center(
        child: Text(
          'Waiting for video...',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 24, 14, 118),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: participants.length <= 2 ? 1 : 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: participants.length,
      itemBuilder: (context, index) {
        final participant = participants[index];
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF251538),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CallAvatar(participant: participant, size: 74),
                const SizedBox(height: 10),
                Text(
                  participant.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CallControlDock extends StatelessWidget {
  const _CallControlDock({
    required this.isVideo,
    required this.onEnd,
    this.onToggleMute,
    this.onToggleCamera,
    this.onSwitchCamera,
    this.onSpeaker,
    this.onMinimize,
  });

  final bool isVideo;
  final VoidCallback onEnd;
  final VoidCallback? onToggleMute;
  final VoidCallback? onToggleCamera;
  final VoidCallback? onSwitchCamera;
  final VoidCallback? onSpeaker;
  final VoidCallback? onMinimize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _RoundCallButton(icon: Icons.mic_off_rounded, color: const Color(0xFF251538), onTap: onToggleMute),
          _RoundCallButton(icon: Icons.volume_up_rounded, color: const Color(0xFF251538), onTap: onSpeaker),
          if (isVideo)
            _RoundCallButton(icon: Icons.cameraswitch_rounded, color: const Color(0xFF251538), onTap: onSwitchCamera),
          if (isVideo)
            _RoundCallButton(icon: Icons.videocam_off_rounded, color: const Color(0xFF251538), onTap: onToggleCamera),
          _RoundCallButton(icon: Icons.open_in_full_rounded, color: const Color(0xFF251538), onTap: onMinimize),
          _RoundCallButton(icon: Icons.call_end_rounded, color: const Color(0xFFE84C72), onTap: onEnd),
        ],
      ),
    );
  }
}

class _CallAvatar extends StatelessWidget {
  const _CallAvatar({required this.participant, required this.size});

  final VmCallParticipantRef? participant;
  final double size;

  @override
  Widget build(BuildContext context) {
    final name = participant?.displayName.trim();
    final initials = name == null || name.isEmpty ? 'VM' : name.characters.take(2).toString().toUpperCase();
    final avatarUrl = participant?.avatarUrl;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [Color(0xFFFF4F9A), Color(0xFF7C3AED)]),
      ),
      child: ClipOval(
        child: avatarUrl == null || avatarUrl.trim().isEmpty
            ? ColoredBox(
                color: const Color(0xFF251538),
                child: Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: size * 0.26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              )
            : Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: const Color(0xFF251538),
                  child: Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: size * 0.26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _RoundCallButton extends StatelessWidget {
  const _RoundCallButton({required this.icon, required this.color, required this.onTap});

  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 21),
      ),
    );
  }
}

class _SummaryAction extends StatelessWidget {
  const _SummaryAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F5FF),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF7C3AED)),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF251538),
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
