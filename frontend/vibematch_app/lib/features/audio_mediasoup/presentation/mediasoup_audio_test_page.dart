import 'dart:async';

import 'package:flutter/material.dart';

import '../data/mediasoup_local_mic_service.dart';
import '../data/mediasoup_socket_service.dart';
import '../models/mediasoup_producer_state.dart';
import '../models/mediasoup_room_state.dart';
import '../models/mediasoup_seat_state.dart';

class MediasoupAudioTestPage extends StatefulWidget {
  const MediasoupAudioTestPage({super.key});

  @override
  State<MediasoupAudioTestPage> createState() => _MediasoupAudioTestPageState();
}

class _MediasoupAudioTestPageState extends State<MediasoupAudioTestPage> {
  static const Color _bg = Color(0xFF120B1E);
  static const Color _card = Color(0xFF211431);
  static const Color _aqua = Color(0xFF12C7B7);
  static const Color _gold = Color(0xFFC99A3B);
  static const Color _pink = Color(0xFFE84C72);

  final MediasoupSocketService _socketService = MediasoupSocketService();
  final MediasoupLocalMicService _micService = MediasoupLocalMicService();

  final TextEditingController _serverController = TextEditingController(text: 'http://10.0.2.2:4000');
  final TextEditingController _roomController = TextEditingController(text: 'VM1001');
  final TextEditingController _peerController = TextEditingController(text: '6418000001');

  final List<String> _logs = <String>[];
  final List<StreamSubscription<dynamic>> _subscriptions = <StreamSubscription<dynamic>>[];

  MediasoupRoomState _roomState = MediasoupRoomState.empty();
  bool _busy = false;
  bool _joined = false;
  bool _micStarted = false;
  bool _selfMuted = false;
  int? _mySeatNo;

  @override
  void initState() {
    super.initState();
    _subscriptions.add(_socketService.logs.listen(_addLog));
    _subscriptions.add(_socketService.seatEvents.listen(_handleSeatEvent));
    _subscriptions.add(_socketService.newProducers.listen(_handleNewProducer));
    _subscriptions.add(_socketService.peerLeftEvents.listen((peerId) {
      _addLog('peer left event received: $peerId');
    }));
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _socketService.dispose();
    _micService.dispose();
    _serverController.dispose();
    _roomController.dispose();
    _peerController.dispose();
    super.dispose();
  }

  Future<void> _joinRoom() async {
    await _runBusy(() async {
      final serverUrl = _serverController.text.trim();
      final roomId = _roomController.text.trim();
      final peerId = _peerController.text.trim();

      if (serverUrl.isEmpty || roomId.isEmpty || peerId.isEmpty) {
        _showSnack('Server URL, room ID, and peer ID are required.');
        return;
      }

      final state = await _socketService.connectAndJoin(
        serverUrl: serverUrl,
        roomId: roomId,
        peerId: peerId,
      );

      setState(() {
        _roomState = state;
        _joined = true;
        _mySeatNo = _findMySeatNo(state.seats);
      });

      _addLog('room joined with ${state.seats.length} seats and ${state.producers.length} producers');
    });
  }

  Future<void> _disconnect() async {
    await _runBusy(() async {
      await _micService.stopMic();
      await _socketService.disconnect();

      setState(() {
        _joined = false;
        _micStarted = false;
        _selfMuted = false;
        _mySeatNo = null;
        _roomState = MediasoupRoomState.empty(roomId: _roomController.text.trim());
      });

      _addLog('disconnected');
    });
  }

  Future<void> _takeSeat(int seatNo) async {
    if (!_joined) {
      _showSnack('Join a room first.');
      return;
    }

    await _runBusy(() async {
      final response = await _socketService.takeSeat(seatNo);
      final seats = MediasoupRoomState.seatsFromEvent(response);
      _applySeats(seats);
      _addLog('seat $seatNo taken');
    });
  }

  Future<void> _leaveSeat() async {
    if (!_joined) return;

    await _runBusy(() async {
      final response = await _socketService.leaveSeat();
      final seats = MediasoupRoomState.seatsFromEvent(response);
      _applySeats(seats);
      setState(() => _mySeatNo = null);
      _addLog('seat left');
    });
  }

  Future<void> _startMic() async {
    if (!_joined) {
      _showSnack('Join a room first.');
      return;
    }

    if (_mySeatNo == null) {
      _showSnack('Take a seat before starting mic.');
      return;
    }

    await _runBusy(() async {
      await _micService.startMic();
      _micService.setMuted(_selfMuted);
      setState(() => _micStarted = true);
      _addLog('local mic started. SFU publish wiring is next step.');
    });
  }

  Future<void> _stopMic() async {
    await _runBusy(() async {
      await _micService.stopMic();
      setState(() {
        _micStarted = false;
        _selfMuted = false;
      });
      _addLog('local mic stopped');
    });
  }

  Future<void> _toggleSelfMute() async {
    if (!_joined || _mySeatNo == null) {
      _showSnack('Take a seat first.');
      return;
    }

    await _runBusy(() async {
      final nextMuted = !_selfMuted;
      final response = await _socketService.setSelfMuted(nextMuted);
      final seats = MediasoupRoomState.seatsFromEvent(response);
      _micService.setMuted(nextMuted);
      setState(() => _selfMuted = nextMuted);
      _applySeats(seats);
      _addLog('self mute changed to $nextMuted');
    });
  }

  void _handleSeatEvent(List<dynamic> rawSeats) {
    final seats = rawSeats
        .whereType<Map>()
        .map((item) => MediasoupSeatState.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
    _applySeats(seats);
  }

  void _handleNewProducer(MediasoupProducerState producer) {
    final exists = _roomState.producers.any((item) => item.producerId == producer.producerId);
    if (exists) return;

    setState(() {
      _roomState = _roomState.copyWith(
        producers: <MediasoupProducerState>[
          ..._roomState.producers,
          producer,
        ],
      );
    });
  }

  void _applySeats(List<MediasoupSeatState> seats) {
    if (seats.isEmpty) return;

    setState(() {
      _roomState = _roomState.copyWith(seats: seats);
      _mySeatNo = _findMySeatNo(seats);
    });
  }

  int? _findMySeatNo(List<MediasoupSeatState> seats) {
    final peerId = _peerController.text.trim();
    for (final seat in seats) {
      if (seat.peerId == peerId) return seat.seatNo;
    }
    return null;
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      _addLog('error: $error');
      _showSnack(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _addLog(String message) {
    if (!mounted) return;
    setState(() {
      _logs.insert(0, message);
      if (_logs.length > 80) {
        _logs.removeRange(80, _logs.length);
      }
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('mediasoup Audio Test'),
        actions: [
          IconButton(
            tooltip: 'Clear logs',
            onPressed: () => setState(_logs.clear),
            icon: const Icon(Icons.cleaning_services_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _buildConnectionCard(),
            const SizedBox(height: 14),
            _buildStatusCard(),
            const SizedBox(height: 14),
            _buildControlsCard(),
            const SizedBox(height: 14),
            _buildSeatsGrid(),
            const SizedBox(height: 14),
            _buildLogsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionCard() {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Local SFU connection',
            subtitle: 'Use different room IDs to test multiple rooms on the same server.',
          ),
          const SizedBox(height: 12),
          _Field(controller: _serverController, label: 'Server URL'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _Field(controller: _roomController, label: 'Room ID')),
              const SizedBox(width: 10),
              Expanded(child: _Field(controller: _peerController, label: 'Peer ID')),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _joinRoom,
                  style: FilledButton.styleFrom(backgroundColor: _aqua, foregroundColor: _bg),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Join / Switch room'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _disconnect,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Disconnect'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return _CardShell(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _StatusPill(label: _joined ? 'Connected' : 'Disconnected', color: _joined ? _aqua : Colors.white54),
          _StatusPill(label: 'Room ${_roomState.roomId}', color: _gold),
          _StatusPill(label: '${_roomState.occupiedSeatCount}/17 seats', color: _aqua),
          _StatusPill(label: '${_roomState.activeProducerCount} producers', color: _pink),
          _StatusPill(label: _mySeatNo == null ? 'Audience' : 'Seat $_mySeatNo', color: _mySeatNo == null ? Colors.white54 : _gold),
          _StatusPill(label: _micStarted ? 'Mic ready' : 'Mic off', color: _micStarted ? _aqua : Colors.white54),
          _StatusPill(label: _selfMuted ? 'Muted' : 'Unmuted', color: _selfMuted ? _pink : _aqua),
        ],
      ),
    );
  }

  Widget _buildControlsCard() {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Seat and mic controls',
            subtitle: 'This test keeps audio isolated from the production Live Room.',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy || !_joined || _mySeatNo == null ? null : _startMic,
                  style: FilledButton.styleFrom(backgroundColor: _aqua, foregroundColor: _bg),
                  icon: const Icon(Icons.mic_rounded),
                  label: const Text('Start local mic'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy || !_micStarted ? null : _stopMic,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                  icon: const Icon(Icons.mic_off_rounded),
                  label: const Text('Stop mic'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy || !_joined || _mySeatNo == null ? null : _toggleSelfMute,
                  style: OutlinedButton.styleFrom(foregroundColor: _selfMuted ? _pink : _aqua),
                  icon: Icon(_selfMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded),
                  label: Text(_selfMuted ? 'Unmute state' : 'Mute state'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy || !_joined || _mySeatNo == null ? null : _leaveSeat,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                  icon: const Icon(Icons.event_seat_rounded),
                  label: const Text('Leave seat'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Next patch will connect mediasoup send/receive transports to this page. This patch validates multi-room signaling, 17-seat state, and local mic capture safely first.',
            style: TextStyle(color: Colors.white60, fontSize: 12.5, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildSeatsGrid() {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: '17 SFU seats',
            subtitle: 'Tap an empty seat to become a speaker in this test room.',
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _roomState.seats.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.92,
            ),
            itemBuilder: (context, index) {
              final seat = _roomState.seats[index];
              final mine = seat.peerId == _peerController.text.trim();
              return _SeatTile(
                seat: seat,
                mine: mine,
                onTap: () {
                  if (seat.occupied && !mine) {
                    _showSnack('Seat ${seat.seatNo} is occupied by ${seat.peerId}.');
                    return;
                  }
                  _takeSeat(seat.seatNo);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLogsCard() {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Test logs',
            subtitle: 'Use this to verify multi-room socket events during local testing.',
          ),
          const SizedBox(height: 10),
          if (_logs.isEmpty)
            const Text('No logs yet.', style: TextStyle(color: Colors.white54))
          else
            for (final log in _logs.take(30))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  log,
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.25),
                ),
              ),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _MediasoupAudioTestPageState._card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.white60, fontSize: 12.5, height: 1.3),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _MediasoupAudioTestPageState._aqua),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _SeatTile extends StatelessWidget {
  const _SeatTile({required this.seat, required this.mine, required this.onTap});

  final MediasoupSeatState seat;
  final bool mine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = mine
        ? _MediasoupAudioTestPageState._gold
        : seat.occupied
            ? _MediasoupAudioTestPageState._pink
            : _MediasoupAudioTestPageState._aqua;

    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                seat.occupied ? Icons.record_voice_over_rounded : Icons.event_seat_rounded,
                color: color,
                size: 24,
              ),
              const SizedBox(height: 7),
              Text(
                'Seat ${seat.seatNo}',
                style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                mine
                    ? 'You'
                    : seat.occupied
                        ? seat.peerId ?? 'Occupied'
                        : 'Empty',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w700),
              ),
              if (seat.muted) ...[
                const SizedBox(height: 3),
                const Icon(Icons.volume_off_rounded, color: _MediasoupAudioTestPageState._pink, size: 15),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
