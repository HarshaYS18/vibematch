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
        joining: _joining,
        error: _presenceError,
        onRefresh: _heartbeat,
        onRetryJoin: _joinPresence,
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
          top: MediaQuery.paddingOf(context).top + 8,
          right: 70,
          width: 96,
          height: 48,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _presenceError == null ? _openParticipantsSheet : _joinPresence,
              borderRadius: BorderRadius.circular(999),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ],
    );
  }
}

class _RealParticipantsSheet extends StatelessWidget {
  const _RealParticipantsSheet({
    required this.roomName,
    required this.participants,
    required this.onlineCount,
    required this.joining,
    required this.error,
    required this.onRefresh,
    required this.onRetryJoin,
  });

  final String roomName;
  final List<SeatUser> participants;
  final int onlineCount;
  final bool joining;
  final String? error;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onRetryJoin;

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
              if (joining)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF12C7B7)))
              else
                Text('$onlineCount online', style: const TextStyle(color: Color(0xFF12C7B7), fontSize: 12, fontWeight: FontWeight.w900)),
              IconButton(onPressed: () => error == null ? unawaited(onRefresh()) : unawaited(onRetryJoin()), icon: Icon(error == null ? Icons.refresh_rounded : Icons.sync_problem_rounded, color: Colors.white70)),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFE84C72).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE84C72).withValues(alpha: 0.28))),
              child: Text(error!, style: const TextStyle(color: Color(0xFFFFB4C4), fontSize: 12, fontWeight: FontWeight.w800)),
            ),
          ],
          const SizedBox(height: 8),
          if (participants.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Text('No active users yet. Refresh after another user joins.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: participants.length,
                separatorBuilder: (context, index) => Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
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
