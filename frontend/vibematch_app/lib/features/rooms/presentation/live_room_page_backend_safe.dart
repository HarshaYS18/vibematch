import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../auth/data/auth_api_service.dart';
import '../../auth/models/current_user.dart';
import '../audio/live_room_audio_controller.dart';
import '../realtime/live_room_realtime_event.dart';
import '../realtime/live_room_realtime_hub.dart';
import 'live_room_models.dart';
import 'widgets/room_seats.dart';
import 'widgets/room_theme.dart';

class LiveRoomPageBackendSafe extends StatefulWidget {
  const LiveRoomPageBackendSafe({
    super.key,
    this.roomName = 'Live Room',
    this.roomId = '',
    this.language = 'English',
    this.modeTitle = 'Open',
    this.onlineCount = 0,
  });

  final String roomName;
  final String roomId;
  final String language;
  final String modeTitle;
  final int onlineCount;

  @override
  State<LiveRoomPageBackendSafe> createState() => _LiveRoomPageBackendSafeState();
}

class _LiveRoomPageBackendSafeState extends State<LiveRoomPageBackendSafe> {
  static const int _seatCount = 10;

  final AuthApiService _authApi = AuthApiService();
  final LiveRoomAudioController _audioController = LiveRoomAudioController();
  final TextEditingController _chatController = TextEditingController();

  StreamSubscription<LiveRoomRealtimeEvent>? _roomEventSub;
  CurrentUser? _currentUser;
  List<RoomSeat> _seats = List<RoomSeat>.generate(_seatCount, (index) => RoomSeat(index: index));
  final List<String> _messages = <String>[];
  bool _loading = true;
  bool _actionInProgress = false;
  bool _micBusy = false;
  String? _error;
  int _onlineCount = 0;

  bool get _isOfficialOrManager {
    final user = _currentUser;
    if (user == null) return false;
    return user.roles.any(
      (role) => <String>{'founder_owner', 'super_owner', 'owner', 'superadmin', 'admin'}.contains(role),
    );
  }

  bool get _isOnSeat {
    final user = _currentUser;
    if (user == null) return false;
    return _seats.any((seat) => seat.user?.id == user.id.toString());
  }

  int get _currentSeatIndex {
    final user = _currentUser;
    if (user == null) return -1;
    return _seats.indexWhere((seat) => seat.user?.id == user.id.toString());
  }

  @override
  void initState() {
    super.initState();
    _onlineCount = widget.onlineCount;
    _audioController.addListener(_onAudioChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapRoom());
  }

  @override
  void dispose() {
    _roomEventSub?.cancel();
    LiveRoomRealtimeHub.disconnect();
    _audioController.removeListener(_onAudioChanged);
    _audioController.leaveRoomAudio();
    _audioController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _bootstrapRoom() async {
    try {
      final user = await _authApi.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _currentUser = user;
        _loading = false;
      });

      _roomEventSub = LiveRoomRealtimeHub.events.listen(_handleRealtimeEvent);
      await LiveRoomRealtimeHub.connect(widget.roomId);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _onAudioChanged() {
    if (mounted) setState(() {});
  }

  void _handleRealtimeEvent(LiveRoomRealtimeEvent event) {
    if (!mounted) return;

    if (event.type == 'room/snapshot' || event.type == 'room/presence') {
      final onlineCount = _readInt(event.payload['online_count']);
      final seatsPayload = event.payload['seats'];
      setState(() {
        if (onlineCount != null) _onlineCount = onlineCount;
        if (seatsPayload is List) _applyBackendSeats(seatsPayload);
      });
      return;
    }

    if (event.type == 'room/seats_updated') {
      final seatsPayload = event.payload['seats'];
      if (seatsPayload is List) setState(() => _applyBackendSeats(seatsPayload));
      final changedSeat = event.payload['changed_seat'];
      if (changedSeat is Map) _maybeAutoStartMicFromSeat(changedSeat.cast<String, dynamic>());
      return;
    }

    if (event.type == 'room/chat/message') {
      final sender = event.payload['sender'];
      final senderName = sender is Map ? sender['display_name']?.toString() : null;
      final message = event.payload['message']?.toString().trim();
      if (message != null && message.isNotEmpty) {
        setState(() => _messages.insert(0, '${senderName ?? 'User'}: $message'));
      }
      return;
    }

    if (event.type == 'room/user_joined') {
      final user = event.payload['user'];
      final name = user is Map ? user['display_name']?.toString() : null;
      setState(() => _messages.insert(0, '${name ?? 'Someone'} joined the room'));
      return;
    }

    if (event.type == 'room/user_left') {
      final user = event.payload['user'];
      final name = user is Map ? user['display_name']?.toString() : null;
      setState(() => _messages.insert(0, '${name ?? 'Someone'} left the room'));
    }
  }

  void _applyBackendSeats(List<dynamic> backendSeats) {
    final nextSeats = List<RoomSeat>.generate(_seatCount, (index) => RoomSeat(index: index));
    for (final rawSeat in backendSeats) {
      if (rawSeat is! Map) continue;
      final seat = rawSeat.cast<String, dynamic>();
      final seatIndex = _readInt(seat['seat_index']) ?? ((_readInt(seat['seat_no']) ?? 1) - 1);
      if (seatIndex < 0 || seatIndex >= nextSeats.length) continue;
      nextSeats[seatIndex] = RoomSeat(
        index: seatIndex,
        locked: seat['locked'] == true,
        user: _seatUserFromBackendSeat(seat),
      );
    }
    _seats = nextSeats;
  }

  SeatUser _seatUserFromBackendSeat(Map<String, dynamic> seat) {
    final userId = _readInt(seat['user_id'])?.toString() ?? 'unknown';
    final publicUserId = _readInt(seat['public_user_id'])?.toString() ?? userId;
    final displayName = seat['display_name']?.toString().trim();
    final isCurrentUser = _currentUser?.id.toString() == userId;
    final name = displayName == null || displayName.isEmpty ? 'User $publicUserId' : displayName;
    final isManager = isCurrentUser && _isOfficialOrManager;

    return SeatUser(
      id: userId,
      name: isCurrentUser ? (_currentUser?.displayName ?? _currentUser?.username ?? name) : name,
      roleLabel: isManager ? 'Room Host' : 'Member',
      familyName: '',
      relationshipText: '',
      vipLevel: 0,
      sendingLevel: 0,
      receivingLevel: 0,
      sentExp: 0,
      receivedExp: 0,
      medals: const <String>[],
      avatarColors: isManager
          ? const <Color>[Color(0xFFFFC857), Color(0xFFE84C72), Color(0xFF8C5CF6)]
          : const <Color>[Color(0xFF12C7B7), Color(0xFF6D5DF6)],
      isCurrentUser: isCurrentUser,
      isHost: isManager,
      isRoomAdmin: isManager,
      selfMuted: seat['self_muted'] == true,
      adminMuted: seat['admin_muted'] == true,
    );
  }

  void _maybeAutoStartMicFromSeat(Map<String, dynamic> seat) {
    final user = _currentUser;
    if (user == null) return;
    final userId = _readInt(seat['user_id']);
    final seatIndex = _readInt(seat['seat_index']) ?? ((_readInt(seat['seat_no']) ?? 1) - 1);
    final shouldAutoStart = seat['auto_start_mic'] == true;
    if (userId == user.id && shouldAutoStart && seatIndex >= 0) {
      _publishMicForSeat(seatIndex, auto: true);
    }
  }

  Future<void> _takeSeat(int seatIndex) async {
    if (_actionInProgress) return;
    setState(() => _actionInProgress = true);
    try {
      final result = await LiveRoomRealtimeHub.requestSeatTake(seatIndex);
      final seats = result.payload['seats'];
      if (mounted && seats is List) setState(() => _applyBackendSeats(seats));
      await _publishMicForSeat(seatIndex);
    } catch (error) {
      if (mounted) _toast(error.toString());
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _leaveSeat() async {
    final seatIndex = _currentSeatIndex;
    if (seatIndex < 0 || _actionInProgress) return;
    setState(() => _actionInProgress = true);
    try {
      final result = await LiveRoomRealtimeHub.requestSeatLeave(seatIndex);
      final seats = result.payload['seats'];
      if (mounted && seats is List) setState(() => _applyBackendSeats(seats));
      await _audioController.leaveSeat();
    } catch (error) {
      if (mounted) _toast(error.toString());
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _publishMicForSeat(int seatIndex, {bool auto = false}) async {
    if (!AppConstants.useMediasoupAudioInLiveRoom || _micBusy) return;
    setState(() => _micBusy = true);
    try {
      await _audioController.joinRoomAudio(widget.roomId);
      await _audioController.takeSeatAndPublish(seatIndex);
      if (mounted) _toast(auto ? 'Host mic connected on seat 1' : 'Mic live on seat ${seatIndex + 1}');
    } catch (error) {
      if (mounted) _toast('Mic failed: $error');
    } finally {
      if (mounted) setState(() => _micBusy = false);
    }
  }

  Future<void> _toggleMic() async {
    final seatIndex = _currentSeatIndex;
    if (seatIndex < 0) {
      _toast('Take a seat before using mic');
      return;
    }
    if (!_audioController.publishing) {
      await _publishMicForSeat(seatIndex);
      return;
    }
    try {
      await _audioController.toggleSelfMute();
      await LiveRoomRealtimeHub.requestMuteState(seatIndex: seatIndex, muted: _audioController.selfMuted, adminMuted: false);
    } catch (error) {
      _toast('Mute failed: $error');
    }
  }

  void _sendMessage() {
    final message = _chatController.text.trim();
    if (message.isEmpty) return;
    _chatController.clear();
    setState(() => _messages.insert(0, 'You: $message'));
    LiveRoomRealtimeHub.sendChatMessage(message);
  }

  void _onSeatTap(int index) {
    final seat = _seats[index];
    if (seat.user != null) {
      _toast('${seat.user!.name} is on seat ${index + 1}');
      return;
    }
    if (index == 0 && !_isOfficialOrManager) {
      _toast('Seat 1 is reserved for owner/admin/members');
      return;
    }
    _takeSeat(index);
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

  int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D1020),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF12C7B7))),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D1020),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_rounded, color: Color(0xFFE84C72), size: 44),
                  const SizedBox(height: 12),
                  const Text('Could not enter room', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D1020),
      body: Stack(
        children: [
          const Positioned.fill(child: RoomBackground(theme: defaultDarkRoomBackgroundTheme)),
          SafeArea(
            child: Column(
              children: [
                _RoomTopBar(
                  roomName: widget.roomName,
                  roomId: widget.roomId,
                  language: widget.language,
                  modeTitle: widget.modeTitle,
                  onlineCount: _onlineCount,
                  onBack: () => Navigator.pop(context),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: RoomSeatLayout(
                    seats: _seats,
                    layoutId: '5x2',
                    selectedSeatIndex: null,
                    canManageSeats: _isOfficialOrManager,
                    onSeatTap: _onSeatTap,
                    onUserTap: (index) => _toast(_seats[index].user?.name ?? 'Seat ${index + 1}'),
                    onInvite: (index) => _toast('Invite flow will use backend room members'),
                    onSwitch: _takeSeat,
                    onLock: (index) => _toast('Seat lock backend action will connect next'),
                    onUnlock: (index) => _toast('Seat unlock backend action will connect next'),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(child: _ChatList(messages: _messages)),
                _RoomComposer(
                  controller: _chatController,
                  micMuted: _audioController.selfMuted,
                  micLive: _audioController.publishing,
                  actionBusy: _actionInProgress || _micBusy,
                  isOnSeat: _isOnSeat,
                  onMicTap: _toggleMic,
                  onSend: _sendMessage,
                  onLeaveSeat: _leaveSeat,
                ),
              ],
            ),
          ),
          if (_actionInProgress || _micBusy)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.08),
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(color: Color(0xFF12C7B7)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoomTopBar extends StatelessWidget {
  const _RoomTopBar({required this.roomName, required this.roomId, required this.language, required this.modeTitle, required this.onlineCount, required this.onBack});

  final String roomName;
  final String roomId;
  final String language;
  final String modeTitle;
  final int onlineCount;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 4),
      child: Row(
        children: [
          IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 19)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(roomName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  _TopPill(text: roomId, icon: Icons.tag_rounded),
                  _TopPill(text: language, icon: Icons.language_rounded),
                  _TopPill(text: modeTitle, icon: Icons.public_rounded),
                  _TopPill(text: '$onlineCount online', icon: Icons.people_rounded),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopPill extends StatelessWidget {
  const _TopPill({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: const Color(0xFF12C7B7), size: 12),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _ChatList extends StatelessWidget {
  const _ChatList({required this.messages});

  final List<String> messages;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(18)),
          child: const Text('No room messages yet', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
        ),
      );
    }

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      itemCount: messages.length,
      itemBuilder: (context, index) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(15)),
          child: Text(messages[index], style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

class _RoomComposer extends StatelessWidget {
  const _RoomComposer({required this.controller, required this.micMuted, required this.micLive, required this.actionBusy, required this.isOnSeat, required this.onMicTap, required this.onSend, required this.onLeaveSeat});

  final TextEditingController controller;
  final bool micMuted;
  final bool micLive;
  final bool actionBusy;
  final bool isOnSeat;
  final VoidCallback onMicTap;
  final VoidCallback onSend;
  final VoidCallback onLeaveSeat;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(color: const Color(0xFF0D1020).withValues(alpha: 0.88), border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.10)))),
        child: Row(children: [
          IconButton(onPressed: actionBusy ? null : onMicTap, icon: Icon(micLive ? (micMuted ? Icons.mic_off_rounded : Icons.mic_rounded) : Icons.mic_none_rounded, color: micLive ? const Color(0xFF12C7B7) : Colors.white70)),
          if (isOnSeat) IconButton(onPressed: actionBusy ? null : onLeaveSeat, icon: const Icon(Icons.call_end_rounded, color: Color(0xFFE84C72))),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              decoration: InputDecoration(hintText: 'Message room', hintStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: Colors.white.withValues(alpha: 0.09), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11)),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(onPressed: onSend, icon: const Icon(Icons.send_rounded, color: Color(0xFF12C7B7))),
        ]),
      ),
    );
  }
}
