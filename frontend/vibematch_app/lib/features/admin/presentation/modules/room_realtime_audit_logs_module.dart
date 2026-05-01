import 'package:flutter/material.dart';

import '../../data/admin_api_service.dart';
import '../../models/room_realtime_audit_log.dart';

class RoomRealtimeAuditLogsModule extends StatefulWidget {
  const RoomRealtimeAuditLogsModule({super.key});

  @override
  State<RoomRealtimeAuditLogsModule> createState() =>
      _RoomRealtimeAuditLogsModuleState();
}

class _RoomRealtimeAuditLogsModuleState
    extends State<RoomRealtimeAuditLogsModule> {
  final AdminApiService _adminApiService = AdminApiService();
  final TextEditingController _roomIdController = TextEditingController();
  final TextEditingController _actorIdController = TextEditingController();

  bool _loading = true;
  String? _error;
  String _mode = 'latest';
  String? _eventType;
  List<RoomRealtimeAuditLog> _logs = const [];

  static const List<String> _eventTypes = [
    'room.seat.occupy',
    'room.seat.leave',
    'room.seat.switch',
    'room.seat.lock',
    'room.seat.unlock',
    'room.mic.self_mute',
    'room.mic.self_unmute',
    'room.mic.admin_mute',
    'room.mic.admin_unmute',
  ];

  @override
  void initState() {
    super.initState();
    _loadLatest();
  }

  @override
  void dispose() {
    _roomIdController.dispose();
    _actorIdController.dispose();
    super.dispose();
  }

  Future<void> _loadLatest() async {
    setState(() {
      _mode = 'latest';
      _loading = true;
      _error = null;
    });

    try {
      final logs = await _adminApiService.getRoomRealtimeAuditLogs(limit: 100);
      if (!mounted) return;
      setState(() => _logs = logs);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadByRoom() async {
    final roomId = _roomIdController.text.trim();
    if (roomId.isEmpty) {
      _showToast('Enter a room ID first');
      return;
    }

    setState(() {
      _mode = 'room';
      _loading = true;
      _error = null;
    });

    try {
      final logs = await _adminApiService.getRoomRealtimeAuditLogsForRoom(
        roomId: roomId,
        eventType: _eventType,
        limit: 100,
      );
      if (!mounted) return;
      setState(() => _logs = logs);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadByActor() async {
    final actorId = _actorIdController.text.trim();
    if (actorId.isEmpty) {
      _showToast('Enter actor user ID first');
      return;
    }

    setState(() {
      _mode = 'actor';
      _loading = true;
      _error = null;
    });

    try {
      final logs = await _adminApiService.getRoomRealtimeAuditLogsForActor(
        actorUserId: actorId,
        limit: 100,
      );
      if (!mounted) return;
      setState(() => _logs = logs);
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

  Future<void> _refreshCurrent() async {
    if (_mode == 'room') return _loadByRoom();
    if (_mode == 'actor') return _loadByActor();
    return _loadLatest();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F5FF),
        elevation: 0,
        foregroundColor: const Color(0xFF21152F),
        title: const Text(
          'Room Realtime Audit',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _refreshCurrent,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshCurrent,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          children: [
            _AuditHeader(total: _logs.length, mode: _mode),
            const SizedBox(height: 14),
            _FilterPanel(
              roomIdController: _roomIdController,
              actorIdController: _actorIdController,
              selectedEventType: _eventType,
              eventTypes: _eventTypes,
              onEventChanged: (value) {
                setState(() => _eventType = value);
                if (_mode == 'room' && _roomIdController.text.trim().isNotEmpty) {
                  _loadByRoom();
                }
              },
              onLatestTap: _loadLatest,
              onRoomTap: _loadByRoom,
              onActorTap: _loadByActor,
              onClearEvent: () {
                setState(() => _eventType = null);
                if (_mode == 'room') _loadByRoom();
              },
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF6D5DF6)),
                ),
              )
            else if (_error != null)
              _ErrorCard(message: _error!, onRetry: _refreshCurrent)
            else if (_logs.isEmpty)
              const _EmptyCard()
            else
              ..._logs.map(
                (log) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AuditLogCard(log: log),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AuditHeader extends StatelessWidget {
  const _AuditHeader({required this.total, required this.mode});

  final int total;
  final String mode;

  @override
  Widget build(BuildContext context) {
    final label = switch (mode) {
      'room' => 'Room filter',
      'actor' => 'Actor filter',
      _ => 'Latest logs',
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF21152F), Color(0xFF5B3BA8), Color(0xFF12C7B7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5B3BA8).withValues(alpha: 0.24),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
            ),
            child: const Icon(Icons.history_edu_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  '$total visible realtime room action logs',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.roomIdController,
    required this.actorIdController,
    required this.selectedEventType,
    required this.eventTypes,
    required this.onEventChanged,
    required this.onLatestTap,
    required this.onRoomTap,
    required this.onActorTap,
    required this.onClearEvent,
  });

  final TextEditingController roomIdController;
  final TextEditingController actorIdController;
  final String? selectedEventType;
  final List<String> eventTypes;
  final ValueChanged<String?> onEventChanged;
  final VoidCallback onLatestTap;
  final VoidCallback onRoomTap;
  final VoidCallback onActorTap;
  final VoidCallback onClearEvent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE9E2F4)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _ActionButton(label: 'Latest', icon: Icons.bolt_rounded, onTap: onLatestTap)),
              const SizedBox(width: 9),
              Expanded(child: _ActionButton(label: 'Room', icon: Icons.meeting_room_rounded, onTap: onRoomTap)),
              const SizedBox(width: 9),
              Expanded(child: _ActionButton(label: 'Actor', icon: Icons.person_search_rounded, onTap: onActorTap)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: roomIdController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onRoomTap(),
            decoration: _fieldDecoration('Room ID, e.g. VM551482', Icons.tag_rounded),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: actorIdController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onActorTap(),
            decoration: _fieldDecoration('Actor ID, e.g. founder_owner', Icons.badge_rounded),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedEventType,
                  items: eventTypes
                      .map((type) => DropdownMenuItem(value: type, child: Text(type, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: onEventChanged,
                  decoration: _fieldDecoration('Event type filter', Icons.filter_alt_rounded),
                ),
              ),
              if (selectedEventType != null) ...[
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: onClearEvent,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: const Color(0xFF6D5DF6)),
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF8F5FF),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF21152F),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      ),
    );
  }
}

class _AuditLogCard extends StatelessWidget {
  const _AuditLogCard({required this.log});

  final RoomRealtimeAuditLog log;

  @override
  Widget build(BuildContext context) {
    final color = _eventColor(log.eventType);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.20)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(_eventIcon(log.eventType), color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        log.shortEventLabel,
                        style: const TextStyle(color: Color(0xFF21152F), fontSize: 15.5, fontWeight: FontWeight.w900),
                      ),
                    ),
                    Text('#${log.id}', style: const TextStyle(color: Color(0xFF8D7EA3), fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  log.actionSummary,
                  style: const TextStyle(color: Color(0xFF5D526D), fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _ChipText('Room ${log.roomId}'),
                    _ChipText('Actor ${log.actorUserId ?? 'unknown'}'),
                    if (log.targetUserId != null) _ChipText('Target ${log.targetUserId}'),
                    _ChipText(_formatTime(log.createdAt)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _eventColor(String type) {
    if (type.contains('lock')) return const Color(0xFFE84C72);
    if (type.contains('mute')) return const Color(0xFFFF9F43);
    if (type.contains('switch')) return const Color(0xFF6D5DF6);
    if (type.contains('occupy')) return const Color(0xFF12C7B7);
    return const Color(0xFF21152F);
  }

  IconData _eventIcon(String type) {
    if (type.contains('lock')) return Icons.lock_rounded;
    if (type.contains('unlock')) return Icons.lock_open_rounded;
    if (type.contains('mute')) return Icons.mic_off_rounded;
    if (type.contains('switch')) return Icons.swap_horiz_rounded;
    if (type.contains('occupy')) return Icons.event_seat_rounded;
    return Icons.history_rounded;
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
  }
}

class _ChipText extends StatelessWidget {
  const _ChipText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF0ECF8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFF5D526D), fontSize: 11.5, fontWeight: FontWeight.w800),
      ),
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
          Icon(Icons.inbox_rounded, color: Color(0xFF8D7EA3), size: 42),
          SizedBox(height: 10),
          Text('No realtime audit logs found', style: TextStyle(color: Color(0xFF21152F), fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
