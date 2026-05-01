import 'package:flutter/material.dart';

import '../../data/admin_api_service.dart';
import '../../models/room_realtime_state.dart';

class RoomStateMonitorModule extends StatefulWidget {
  const RoomStateMonitorModule({super.key});

  @override
  State<RoomStateMonitorModule> createState() => _RoomStateMonitorModuleState();
}

class _RoomStateMonitorModuleState extends State<RoomStateMonitorModule> {
  final AdminApiService _adminApiService = AdminApiService();
  final TextEditingController _roomIdController = TextEditingController(text: 'VM551482');

  bool _loading = false;
  String? _error;
  RoomRealtimeState? _state;

  @override
  void dispose() {
    _roomIdController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final roomId = _roomIdController.text.trim();
    if (roomId.isEmpty) {
      _showToast('Enter a room ID first');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final state = await _adminApiService.getRoomRealtimeState(roomId: roomId);
      if (!mounted) return;
      setState(() => _state = state);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF21152F),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;

    return Scaffold(
      backgroundColor: const Color(0xFFF3FBFA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3FBFA),
        elevation: 0,
        foregroundColor: const Color(0xFF102A32),
        title: const Text(
          'Room State Monitor',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadState,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadState,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          children: [
            _MonitorHeader(state: state),
            const SizedBox(height: 14),
            _SearchPanel(
              controller: _roomIdController,
              loading: _loading,
              onSearch: _loadState,
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF12C7B7)),
                ),
              )
            else if (_error != null)
              _ErrorCard(message: _error!, onRetry: _loadState)
            else if (state == null)
              const _EmptyCard()
            else ...[
              _SummaryGrid(state: state),
              const SizedBox(height: 14),
              const Text(
                'Seats',
                style: TextStyle(
                  color: Color(0xFF102A32),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              if (state.seats.isEmpty)
                const _NoSeatsCard()
              else
                ...state.seats.map(
                  (seat) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SeatStateCard(seat: seat),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MonitorHeader extends StatelessWidget {
  const _MonitorHeader({required this.state});

  final RoomRealtimeState? state;

  @override
  Widget build(BuildContext context) {
    final roomId = state?.roomId.trim().isNotEmpty == true ? state!.roomId : 'Search room';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF102A32), Color(0xFF0C736C), Color(0xFF12C7B7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF12C7B7).withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 62,
            width: 62,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(23),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: const Icon(Icons.radar_rounded, color: Colors.white, size: 34),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(roomId, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(
                  state == null
                      ? 'Fetch active Redis-backed room snapshot.'
                      : 'Updated ${_formatDateTime(state!.updatedAt)}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontWeight: FontWeight.w700, height: 1.25),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.controller,
    required this.loading,
    required this.onSearch,
  });

  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD8F1EE)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSearch(),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.tag_rounded, color: Color(0xFF12C7B7)),
                hintText: 'Room ID, e.g. VM551482',
                filled: true,
                fillColor: const Color(0xFFF3FBFA),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: loading ? null : onSearch,
            icon: const Icon(Icons.search_rounded, size: 18),
            label: const Text('Fetch'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF102A32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.state});

  final RoomRealtimeState state;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.72,
      children: [
        _SummaryTile(label: 'Tracked Seats', value: '${state.seats.length}', icon: Icons.event_seat_rounded, color: const Color(0xFF12C7B7)),
        _SummaryTile(label: 'Occupied', value: '${state.occupiedCount}', icon: Icons.person_rounded, color: const Color(0xFF6D5DF6)),
        _SummaryTile(label: 'Locked', value: '${state.lockedCount}', icon: Icons.lock_rounded, color: const Color(0xFFE84C72)),
        _SummaryTile(label: 'Muted', value: '${state.selfMutedCount + state.adminMutedCount}', icon: Icons.mic_off_rounded, color: const Color(0xFFFF9F43)),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value, required this.icon, required this.color});

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: const TextStyle(color: Color(0xFF102A32), fontSize: 20, fontWeight: FontWeight.w900)),
                Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF6A7C80), fontSize: 11.5, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeatStateCard extends StatelessWidget {
  const _SeatStateCard({required this.seat});

  final RoomRealtimeSeatState seat;

  @override
  Widget build(BuildContext context) {
    final user = seat.user;
    final color = seat.locked
        ? const Color(0xFFE84C72)
        : user != null
            ? const Color(0xFF12C7B7)
            : const Color(0xFF8AA0A4);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.20)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(18)),
            child: Icon(seat.locked ? Icons.lock_rounded : Icons.event_seat_rounded, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Seat ${seat.seatIndex + 1}', style: const TextStyle(color: Color(0xFF102A32), fontSize: 15.5, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  user == null ? (seat.locked ? 'Locked and empty' : 'Empty') : '${user.displayName} · ${user.userId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF607579), fontWeight: FontWeight.w800),
                ),
                if (user != null && (user.selfMuted || user.adminMuted)) ...[
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 6,
                    children: [
                      if (user.selfMuted) const _StatusChip(label: 'Self muted', color: Color(0xFFFF9F43)),
                      if (user.adminMuted) const _StatusChip(label: 'Admin muted', color: Color(0xFFE84C72)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEF2),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE84C72).withValues(alpha: 0.28)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFE84C72), size: 34),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF7B243B), fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: const Column(
        children: [
          Icon(Icons.radar_rounded, color: Color(0xFF8AA0A4), size: 42),
          SizedBox(height: 10),
          Text('Search a room ID to view active state', style: TextStyle(color: Color(0xFF102A32), fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _NoSeatsCard extends StatelessWidget {
  const _NoSeatsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: const Text(
        'No seats tracked yet. Perform a seat action in the live room first.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF607579), fontWeight: FontWeight.w800),
      ),
    );
  }
}
