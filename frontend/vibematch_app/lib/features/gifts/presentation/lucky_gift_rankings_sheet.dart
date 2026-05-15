import 'dart:async';

import 'package:flutter/material.dart';

import '../data/lucky_gifts_api_service.dart';

class LuckyGiftRankingsSheet extends StatefulWidget {
  const LuckyGiftRankingsSheet({
    super.key,
    this.initialType = LuckyGiftRankingType.winnings,
    this.initialPeriod = LuckyGiftPeriod.daily,
  });

  final LuckyGiftRankingType initialType;
  final LuckyGiftPeriod initialPeriod;

  static Future<void> show(
    BuildContext context, {
    LuckyGiftRankingType initialType = LuckyGiftRankingType.winnings,
    LuckyGiftPeriod initialPeriod = LuckyGiftPeriod.daily,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LuckyGiftRankingsSheet(
        initialType: initialType,
        initialPeriod: initialPeriod,
      ),
    );
  }

  @override
  State<LuckyGiftRankingsSheet> createState() => _LuckyGiftRankingsSheetState();
}

class _LuckyGiftRankingsSheetState extends State<LuckyGiftRankingsSheet> {
  final LuckyGiftsApiService _api = const LuckyGiftsApiService();

  late LuckyGiftRankingType _type = widget.initialType;
  late LuckyGiftPeriod _period = widget.initialPeriod;
  LuckyGiftStats? _myStats;
  LuckyGiftRankingResponse? _ranking;
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
        _api.getMyStats(),
        _api.getRanking(type: _type, period: _period, limit: 100),
      ]);
      if (!mounted) return;
      setState(() {
        _myStats = results[0] as LuckyGiftStats;
        _ranking = results[1] as LuckyGiftRankingResponse;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _changeType(LuckyGiftRankingType type) {
    if (_type == type) return;
    setState(() {
      _type = type;
      _ranking = null;
      _error = null;
    });
    unawaited(_load());
  }

  void _changePeriod(LuckyGiftPeriod period) {
    if (_period == period) return;
    setState(() {
      _period = period;
      _ranking = null;
      _error = null;
    });
    unawaited(_load());
  }

  LuckyGiftStatsPeriod? get _visibleStats {
    final stats = _myStats;
    if (stats == null) return null;
    switch (_period) {
      case LuckyGiftPeriod.daily:
        return stats.today;
      case LuckyGiftPeriod.weekly:
        return stats.weekly;
      case LuckyGiftPeriod.monthly:
        return stats.monthly;
      case LuckyGiftPeriod.yearly:
        return stats.yearly;
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = _ranking?.entries ?? const <LuckyGiftRankingEntry>[];
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.84,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A0B28), Color(0xFF2A1244), Color(0xFF40200E)],
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
                _StatsCard(stats: _visibleStats, period: _period),
                const SizedBox(height: 12),
                _TypeTabs(selected: _type, onChanged: _changeType),
                const SizedBox(height: 10),
                _PeriodTabs(selected: _period, onChanged: _changePeriod),
                const SizedBox(height: 12),
                _StatusPill(
                  type: _type,
                  period: _period,
                  count: entries.length,
                  loading: _loading,
                  error: _error,
                  onRefresh: () => unawaited(_load()),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _loading && entries.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(color: Color(0xFFFFC857)),
                        )
                      : entries.isEmpty
                          ? _EmptyState(error: _error, onRetry: () => unawaited(_load()))
                          : RefreshIndicator(
                              onRefresh: _load,
                              color: const Color(0xFFFFC857),
                              child: ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                padding: const EdgeInsets.only(bottom: 12),
                                itemCount: entries.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  return _RankingTile(entry: entries[index], type: _type);
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
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFFC857).withValues(alpha: 0.18),
            border: Border.all(color: const Color(0xFFFFC857).withValues(alpha: 0.42)),
          ),
          child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFC857), size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lucky Gift Rankings',
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
                'Stats, winnings, multipliers and lucky activity',
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

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats, required this.period});

  final LuckyGiftStatsPeriod? stats;
  final LuckyGiftPeriod period;

  @override
  Widget build(BuildContext context) {
    final item = stats;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My lucky stats · ${period.label}',
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _StatPill(label: 'Spent', value: _compact(item?.spentCoins ?? 0)),
              const SizedBox(width: 8),
              _StatPill(label: 'Won', value: _compact(item?.rewardCoins ?? 0)),
              const SizedBox(width: 8),
              _StatPill(label: 'Best', value: '${item?.bestMultiplier ?? 0}x'),
              const SizedBox(width: 8),
              _StatPill(label: 'Rounds', value: '${item?.rounds ?? 0}'),
            ],
          ),
        ],
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFFFC857), fontSize: 12, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.50), fontSize: 9.5, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeTabs extends StatelessWidget {
  const _TypeTabs({required this.selected, required this.onChanged});

  final LuckyGiftRankingType selected;
  final ValueChanged<LuckyGiftRankingType> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: LuckyGiftRankingType.values.length,
        separatorBuilder: (context, index) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final type = LuckyGiftRankingType.values[index];
          final isSelected = selected == type;
          return GestureDetector(
            onTap: () => onChanged(type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: isSelected ? const Color(0xFFFFC857) : Colors.white.withValues(alpha: 0.08),
                border: Border.all(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.10),
                ),
              ),
              child: Text(
                type.label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF170B24) : Colors.white.withValues(alpha: 0.78),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({required this.selected, required this.onChanged});

  final LuckyGiftPeriod selected;
  final ValueChanged<LuckyGiftPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: LuckyGiftPeriod.values.map((period) {
        final isSelected = selected == period;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => onChanged(period),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: isSelected ? Colors.white.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.06),
                  border: Border.all(
                    color: isSelected ? Colors.white.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  period.label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.62),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.type,
    required this.period,
    required this.count,
    required this.loading,
    required this.error,
    required this.onRefresh,
  });

  final LuckyGiftRankingType type;
  final LuckyGiftPeriod period;
  final int count;
  final bool loading;
  final String? error;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final path = '/lucky-gifts/rankings/${type.backendValue}?period=${period.backendValue}';
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
          const Icon(Icons.query_stats_rounded, color: Color(0xFFFFC857), size: 16),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              '$status · GET $path',
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
            '$count ranks',
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

class _RankingTile extends StatelessWidget {
  const _RankingTile({required this.entry, required this.type});

  final LuckyGiftRankingEntry entry;
  final LuckyGiftRankingType type;

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
          SizedBox(
            width: 34,
            child: Text(
              '#${entry.rank}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFFFC857), fontSize: 13, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 21,
            backgroundColor: const Color(0xFFFFC857).withValues(alpha: 0.22),
            backgroundImage: entry.avatarUrl == null ? null : NetworkImage(entry.avatarUrl!),
            child: entry.avatarUrl == null
                ? Text(
                    _initial(entry.displayName),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _compact(entry.score),
                style: const TextStyle(color: Color(0xFFFFC857), fontSize: 13, fontWeight: FontWeight.w900),
              ),
              Text(
                type.label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.42),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.error, required this.onRetry});

  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_outlined, color: Colors.white.withValues(alpha: 0.56), size: 38),
          const SizedBox(height: 10),
          Text(
            error == null ? 'No lucky ranking data yet' : 'Could not load lucky rankings',
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

String _initial(String name) {
  final text = name.trim();
  if (text.isEmpty) return 'V';
  return text.characters.first.toUpperCase();
}

String _compact(int value) {
  if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(1)}B';
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toString();
}
