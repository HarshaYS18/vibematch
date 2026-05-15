import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/room_level_service.dart';
import 'room_theme.dart';

class RoomLevelSheet extends StatefulWidget {
  const RoomLevelSheet({
    super.key,
    required this.roomName,
    required this.roomPublicId,
    this.fallbackLevel = 1,
  });

  final String roomName;
  final String roomPublicId;
  final int fallbackLevel;

  static Future<void> show(
    BuildContext context, {
    required String roomName,
    required String roomPublicId,
    int fallbackLevel = 1,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RoomLevelSheet(
        roomName: roomName,
        roomPublicId: roomPublicId,
        fallbackLevel: fallbackLevel,
      ),
    );
  }

  @override
  State<RoomLevelSheet> createState() => _RoomLevelSheetState();
}

class _RoomLevelSheetState extends State<RoomLevelSheet> {
  RoomLevelSummary? _summary;
  List<RoomLevelHistoryEntry> _history = const <RoomLevelHistoryEntry>[];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait<Object>([
        RoomLevelService.instance.fetchRoomLevel(
          roomPublicId: widget.roomPublicId,
          fallbackLevel: widget.fallbackLevel,
        ),
        RoomLevelService.instance.fetchRoomLevelHistory(
          roomPublicId: widget.roomPublicId,
          limit: 30,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as RoomLevelSummary;
        _history = results[1] as List<RoomLevelHistoryEntry>;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _summary = RoomLevelSummary.fallback(widget.fallbackLevel);
        _history = const <RoomLevelHistoryEntry>[];
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary ?? RoomLevelSummary.fallback(widget.fallbackLevel);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.82,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF150D24), Color(0xFF251544), Color(0xFF3A2508)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              14,
              10,
              14,
              MediaQuery.paddingOf(context).bottom + 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: SheetHandle(width: 44)),
                const SizedBox(height: 14),
                _Header(
                  roomName: widget.roomName,
                  roomPublicId: widget.roomPublicId,
                  level: summary.level,
                  onClose: () => Navigator.pop(context),
                ),
                const SizedBox(height: 14),
                _ProgressCard(summary: summary),
                const SizedBox(height: 12),
                _StatsRow(summary: summary),
                const SizedBox(height: 12),
                _StatusPill(
                  loading: _loading,
                  error: _error,
                  roomPublicId: widget.roomPublicId,
                  onRefresh: () => unawaited(_load()),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Recent EXP history',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _loading && _history.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(color: RoomColors.gold),
                        )
                      : _history.isEmpty
                          ? _EmptyHistory(error: _error, onRetry: () => unawaited(_load()))
                          : RefreshIndicator(
                              onRefresh: _load,
                              color: RoomColors.gold,
                              child: ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                padding: const EdgeInsets.only(bottom: 10),
                                itemCount: _history.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  return _HistoryTile(entry: _history[index]);
                                },
                              ),
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.roomName,
    required this.roomPublicId,
    required this.level,
    required this.onClose,
  });

  final String roomName;
  final String roomPublicId;
  final int level;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                RoomColors.gold.withValues(alpha: 0.95),
                RoomColors.coral.withValues(alpha: 0.80),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
            boxShadow: [
              BoxShadow(
                color: RoomColors.gold.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.local_fire_department_rounded,
            color: Colors.white,
            size: 25,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                roomName.trim().isEmpty ? 'Room Level' : roomName.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Room ID $roomPublicId · Level $level',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.58),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onClose,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.summary});

  final RoomLevelSummary summary;

  @override
  Widget build(BuildContext context) {
    final progress = summary.progress.clamp(0, 1).toDouble();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Lv.${summary.level}',
                style: const TextStyle(
                  color: RoomColors.gold,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  summary.nextLevelExp > 0
                      ? '${_compact(summary.totalExp)} / ${_compact(summary.nextLevelExp)} EXP'
                      : '${_compact(summary.totalExp)} total EXP',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.66),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.black.withValues(alpha: 0.28),
              color: RoomColors.gold,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.summary});

  final RoomLevelSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatPill(label: 'Total EXP', value: _compact(summary.totalExp)),
        const SizedBox(width: 8),
        _StatPill(label: 'Period EXP', value: _compact(summary.periodExp)),
        const SizedBox(width: 8),
        _StatPill(label: 'Rank', value: summary.rank == null ? '--' : '#${summary.rank}'),
        const SizedBox(width: 8),
        _StatPill(label: 'Max Lv', value: '${summary.maxLevel}'),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: RoomColors.gold,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.50),
                fontSize: 9.2,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.loading,
    required this.error,
    required this.roomPublicId,
    required this.onRefresh,
  });

  final bool loading;
  final String? error;
  final String roomPublicId;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final status = loading
        ? 'syncing live...'
        : error == null
            ? 'live backend data'
            : 'fallback: $error';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          const Icon(Icons.query_stats_rounded, color: RoomColors.gold, size: 16),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              '$status · GET /rooms/$roomPublicId/level',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.54),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          GestureDetector(
            onTap: onRefresh,
            child: Icon(
              Icons.refresh_rounded,
              color: Colors.white.withValues(alpha: 0.75),
              size: 17,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final RoomLevelHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: RoomColors.gold.withValues(alpha: 0.16),
              border: Border.all(color: RoomColors.gold.withValues(alpha: 0.24)),
            ),
            child: const Icon(Icons.bolt_rounded, color: RoomColors.gold, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${entry.eventType} · ${_dateLabel(entry.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.46),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '+${_compact(entry.expDelta)}',
            style: const TextStyle(
              color: RoomColors.gold,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.error, required this.onRetry});

  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_outlined,
            color: Colors.white.withValues(alpha: 0.56),
            size: 38,
          ),
          const SizedBox(height: 10),
          Text(
            error == null ? 'No room EXP history yet' : 'Could not load history',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

String _compact(int value) {
  if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(1)}B';
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toString();
}

String _dateLabel(DateTime? value) {
  if (value == null) return 'recent';
  final local = value.toLocal();
  final now = DateTime.now();
  final diff = now.difference(local);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${local.day}/${local.month}/${local.year}';
}
