import 'dart:async';

import 'package:flutter/material.dart';

import '../data/live_room_presence_repository.dart';
import 'live_room_models.dart';
import 'live_room_page.dart';

class LiveRoomPresenceShellPage extends StatefulWidget {
  const LiveRoomPresenceShellPage({
    super.key,
    required this.roomName,
    required this.roomId,
    required this.language,
    required this.modeTitle,
    required this.initialOnlineCount,
  });

  final String roomName;
  final String roomId;
  final String language;
  final String modeTitle;
  final int initialOnlineCount;

  @override
  State<LiveRoomPresenceShellPage> createState() => _LiveRoomPresenceShellPageState();
}

class _LiveRoomPresenceShellPageState extends State<LiveRoomPresenceShellPage> {
  final LiveRoomPresenceRepository _presenceRepository = LiveRoomPresenceRepository();
  Timer? _heartbeatTimer;
  LiveRoomPresenceSnapshot? _snapshot;
  bool _joining = true;
  bool _participantsOpen = false;
  String? _presenceError;

  int get _onlineCount => _snapshot?.onlineCount ?? widget.initialOnlineCount;
  List<SeatUser> get _participants => _snapshot?.participants ?? const <SeatUser>[];

  @override
  void initState() {
    super.initState();
    unawaited(_joinPresence());
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    unawaited(_presenceRepository.leaveRoom(widget.roomId).catchError((_) => 0));
    _presenceRepository.close();
    super.dispose();
  }

  Future<void> _joinPresence() async {
    setState(() {
      _joining = true;
      _presenceError = null;
    });
    try {
      final snapshot = await _presenceRepository.joinRoom(widget.roomId);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _joining = false;
      });
      _startHeartbeat();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _joining = false;
        _presenceError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 12), (_) => unawaited(_heartbeat()));
  }

  Future<void> _heartbeat() async {
    try {
      final snapshot = await _presenceRepository.heartbeat(widget.roomId);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _presenceError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _presenceError = error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _openParticipantsSheet() async {
    if (_participantsOpen) return;
    _participantsOpen = true;
    try {
      final snapshot = await _presenceRepository.fetchParticipants(widget.roomId);
      if (mounted) setState(() => _snapshot = snapshot);
    } catch (_) {}
    if (!mounted) {
      _participantsOpen = false;
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RealParticipantsSheet(
        roomName: widget.roomName,
        participants: _participants,
        onlineCount: _onlineCount,
        onRefresh: _heartbeat,
      ),
    );
    _participantsOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        LiveRoomPage(
          roomName: widget.roomName,
          roomId: widget.roomId,
          language: widget.language,
          modeTitle: widget.modeTitle,
          onlineCount: _onlineCount,
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 74,
          right: 12,
          child: _PresencePill(
            onlineCount: _onlineCount,
            joining: _joining,
            hasError: _presenceError != null,
            onTap: _openParticipantsSheet,
            onRetry: _joinPresence,
          ),
        ),
      ],
    );
  }
}

class _PresencePill extends StatelessWidget {
  const _PresencePill({required this.onlineCount, required this.joining, required this.hasError, required this.onTap, required this.onRetry});

  final int onlineCount;
  final bool joining;
  final bool hasError;
  final VoidCallback onTap;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final color = hasError ? const Color(0xFFE84C72) : const Color(0xFF12C7B7);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: hasError ? onRetry : onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF090714).withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.55)),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.20), blurRadius: 14, offset: const Offset(0, 6))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (joining)
                const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              else
                Icon(hasError ? Icons.refresh_rounded : Icons.people_alt_rounded, color: color, size: 15),
              const SizedBox(width: 6),
              Text(hasError ? 'Retry' : '$onlineCount live', style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RealParticipantsSheet extends StatelessWidget {
  const _RealParticipantsSheet({required this.roomName, required this.participants, required this.onlineCount, required this.onRefresh});

  final String roomName;
  final List<SeatUser> participants;
  final int onlineCount;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.72),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(color: const Color(0xFF120D1F), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white.withValues(alpha: 0.10))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 42, height: 5, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.24), borderRadius: BorderRadius.circular(999))),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: Text(roomName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900))),
              Text('$onlineCount online', style: const TextStyle(color: Color(0xFF12C7B7), fontSize: 12, fontWeight: FontWeight.w900)),
              IconButton(onPressed: () => unawaited(onRefresh()), icon: const Icon(Icons.refresh_rounded, color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 8),
          if (participants.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Text('No active users yet. Pull refresh after another user joins.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: participants.length,
                separatorBuilder: (_, __) => Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                itemBuilder: (context, index) => _ParticipantTile(user: participants[index]),
              ),
            ),
        ],
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({required this.user});

  final SeatUser user;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: user.avatarColors)),
            child: Text(avatarLetter(user.name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(user.roleLabel, style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          if (user.vipLevel > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(color: const Color(0xFFFFC857).withValues(alpha: 0.13), borderRadius: BorderRadius.circular(999)),
              child: Text('VIP ${user.vipLevel}', style: const TextStyle(color: Color(0xFFFFC857), fontSize: 10, fontWeight: FontWeight.w900)),
            ),
        ],
      ),
    );
  }
}
