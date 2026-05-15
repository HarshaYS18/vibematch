import 'dart:async';

import 'package:flutter/material.dart';

import '../data/relationship_exp_api_service.dart';

class RelationshipExpDetailSheet extends StatefulWidget {
  const RelationshipExpDetailSheet({
    super.key,
    required this.publicUserId,
    this.initialSummary,
  });

  final int publicUserId;
  final RelationshipExpSummary? initialSummary;

  static Future<void> show(
    BuildContext context, {
    required int publicUserId,
    RelationshipExpSummary? initialSummary,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RelationshipExpDetailSheet(
        publicUserId: publicUserId,
        initialSummary: initialSummary,
      ),
    );
  }

  @override
  State<RelationshipExpDetailSheet> createState() => _RelationshipExpDetailSheetState();
}

class _RelationshipExpDetailSheetState extends State<RelationshipExpDetailSheet> {
  final RelationshipExpApiService _api = const RelationshipExpApiService();

  RelationshipExpSummary? _summary;
  RelationshipExpMaster? _master;
  List<RelationshipExpHistoryEntry> _history = const <RelationshipExpHistoryEntry>[];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _summary = widget.initialSummary;
    unawaited(_load());
  }

  Future<void> _load() async {
    if (widget.publicUserId <= 0) return;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait<Object>([
        _api.getUserSummary(publicUserId: widget.publicUserId),
        _api.getHistory(otherPublicUserId: widget.publicUserId, limit: 50),
        _api.getMaster(),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as RelationshipExpSummary;
        _history = results[1] as List<RelationshipExpHistoryEntry>;
        _master = results[2] as RelationshipExpMaster;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
      unawaited(_loadMasterOnly());
    }
  }

  Future<void> _loadMasterOnly() async {
    try {
      final master = await _api.getMaster();
      if (!mounted) return;
      setState(() => _master = master);
    } catch (_) {
      // Config preview is optional and must not block the sheet.
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.82,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF250A1F), Color(0xFF42113A), Color(0xFF2B164E)],
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
                const Center(
                  child: SizedBox(
                    width: 44,
                    height: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white54,
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _Header(onClose: () => Navigator.pop(context)),
                const SizedBox(height: 12),
                if (summary != null)
                  _SummaryCard(summary: summary)
                else
                  _NoSummaryCard(loading: _loading, error: _error, onRetry: () => unawaited(_load())),
                const SizedBox(height: 12),
                _StatusPill(
                  publicUserId: widget.publicUserId,
                  loading: _loading,
                  error: _error,
                  historyCount: _history.length,
                  onRefresh: () => unawaited(_load()),
                ),
                const SizedBox(height: 12),
                _RulesPreview(master: _master),
                const SizedBox(height: 12),
                const Text(
                  'Relationship EXP history',
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
                          child: CircularProgressIndicator(color: Color(0xFFFF5AAA)),
                        )
                      : _history.isEmpty
                          ? _EmptyHistory(error: _error, onRetry: () => unawaited(_load()))
                          : RefreshIndicator(
                              onRefresh: _load,
                              color: const Color(0xFFFF5AAA),
                              child: ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                padding: const EdgeInsets.only(bottom: 12),
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
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFF5AAA).withValues(alpha: 0.18),
            border: Border.all(color: const Color(0xFFFF5AAA).withValues(alpha: 0.42)),
          ),
          child: const Icon(Icons.favorite_rounded, color: Color(0xFFFF5AAA), size: 23),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Relationship EXP',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              Text(
                'Bond level, progress, and recent EXP events',
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final RelationshipExpSummary summary;

  @override
  Widget build(BuildContext context) {
    final progress = summary.progress.clamp(0, 1).toDouble();
    final bestPair = summary.bestPair;
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
                'Bond Lv.${summary.level}',
                style: const TextStyle(
                  color: Color(0xFFFF5AAA),
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
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
              minHeight: 8,
              value: progress,
              backgroundColor: Colors.black.withValues(alpha: 0.26),
              color: const Color(0xFFFF5AAA),
            ),
          ),
          if (bestPair != null) ...[
            const SizedBox(height: 10),
            Text(
              'Best bond: ${bestPair.displayName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoSummaryCard extends StatelessWidget {
  const _NoSummaryCard({required this.loading, required this.error, required this.onRetry});

  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onRetry,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          children: [
            if (loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF5AAA)),
              )
            else
              const Icon(Icons.favorite_border_rounded, color: Color(0xFFFF5AAA), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                error == null ? 'Loading relationship EXP...' : 'Relationship EXP unavailable · tap to retry',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
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
    required this.publicUserId,
    required this.loading,
    required this.error,
    required this.historyCount,
    required this.onRefresh,
  });

  final int publicUserId;
  final bool loading;
  final String? error;
  final int historyCount;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final status = loading ? 'syncing live...' : error == null ? 'live backend data' : 'fallback: $error';
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
          const Icon(Icons.query_stats_rounded, color: Color(0xFFFF5AAA), size: 16),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              '$status · GET /relationships/users/$publicUserId/summary',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.54),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            '$historyCount logs',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.70),
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRefresh,
            child: Icon(Icons.refresh_rounded, color: Colors.white.withValues(alpha: 0.75), size: 17),
          ),
        ],
      ),
    );
  }
}

class _RulesPreview extends StatelessWidget {
  const _RulesPreview({required this.master});

  final RelationshipExpMaster? master;

  @override
  Widget build(BuildContext context) {
    final rules = master?.rules ?? const <String, dynamic>{};
    final enabled = master?.enabled ?? true;
    final maxLevel = master?.maxLevel ?? 100;
    final giftExp = _ruleValue(rules, const ['gift_exp_per_coin', 'gift_coin_exp_rate', 'gift']);
    final roomTime = _ruleValue(rules, const ['room_time_exp_per_minute', 'time_exp_per_minute', 'time']);
    final interaction = _ruleValue(rules, const ['interaction_exp', 'daily_interaction_exp', 'interaction']);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, color: Color(0xFFFF5AAA), size: 16),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  enabled ? 'EXP rules · max Lv.$maxLevel' : 'Relationship EXP disabled',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _RuleChip(label: 'Gift', value: giftExp),
              _RuleChip(label: 'Room time', value: roomTime),
              _RuleChip(label: 'Interact', value: interaction),
            ],
          ),
        ],
      ),
    );
  }
}

class _RuleChip extends StatelessWidget {
  const _RuleChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.72),
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final RelationshipExpHistoryEntry entry;

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
              color: const Color(0xFFFF5AAA).withValues(alpha: 0.16),
              border: Border.all(color: const Color(0xFFFF5AAA).withValues(alpha: 0.24)),
            ),
            child: const Icon(Icons.favorite_rounded, color: Color(0xFFFF5AAA), size: 18),
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
                  style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900),
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
            style: const TextStyle(color: Color(0xFFFF5AAA), fontSize: 12.5, fontWeight: FontWeight.w900),
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
          Icon(Icons.favorite_border_rounded, color: Colors.white.withValues(alpha: 0.56), size: 38),
          const SizedBox(height: 10),
          Text(
            error == null ? 'No relationship EXP history yet' : 'Could not load history',
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
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

String _ruleValue(Map<String, dynamic> rules, List<String> keys) {
  for (final key in keys) {
    final value = rules[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return '--';
}
