import 'dart:async';

import 'package:flutter/material.dart';

import '../data/relationship_exp_api_service.dart';

class RelationshipRankingsSheet extends StatefulWidget {
  const RelationshipRankingsSheet({
    super.key,
    this.initialPeriod = RelationshipRankingPeriod.weekly,
  });

  final RelationshipRankingPeriod initialPeriod;

  static Future<void> show(
    BuildContext context, {
    RelationshipRankingPeriod initialPeriod = RelationshipRankingPeriod.weekly,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RelationshipRankingsSheet(initialPeriod: initialPeriod),
    );
  }

  @override
  State<RelationshipRankingsSheet> createState() => _RelationshipRankingsSheetState();
}

class _RelationshipRankingsSheetState extends State<RelationshipRankingsSheet> {
  final RelationshipExpApiService _api = const RelationshipExpApiService();

  late RelationshipRankingPeriod _period = widget.initialPeriod;
  List<RelationshipRankingEntry> _entries = const <RelationshipRankingEntry>[];
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
      final entries = await _api.getRankings(period: _period, limit: 100);
      if (!mounted) return;
      setState(() {
        _entries = entries;
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

  void _changePeriod(RelationshipRankingPeriod period) {
    if (_period == period) return;
    setState(() {
      _period = period;
      _entries = const <RelationshipRankingEntry>[];
      _error = null;
    });
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.82,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF230B1E), Color(0xFF43113B), Color(0xFF28164B)],
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
                _PeriodTabs(selected: _period, onChanged: _changePeriod),
                const SizedBox(height: 12),
                _StatusPill(
                  period: _period,
                  count: _entries.length,
                  loading: _loading,
                  error: _error,
                  onRefresh: () => unawaited(_load()),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _loading && _entries.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(color: Color(0xFFFF5AAA)),
                        )
                      : _entries.isEmpty
                          ? _EmptyState(error: _error, onRetry: () => unawaited(_load()))
                          : RefreshIndicator(
                              onRefresh: _load,
                              color: const Color(0xFFFF5AAA),
                              child: ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                padding: const EdgeInsets.only(bottom: 12),
                                itemCount: _entries.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  return _RelationshipRankTile(entry: _entries[index]);
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
            color: const Color(0xFFFF5AAA).withValues(alpha: 0.18),
            border: Border.all(color: const Color(0xFFFF5AAA).withValues(alpha: 0.42)),
          ),
          child: const Icon(Icons.favorite_rounded, color: Color(0xFFFF5AAA), size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Relationship Rankings',
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
                'Top pairs by relationship EXP',
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

class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({required this.selected, required this.onChanged});

  final RelationshipRankingPeriod selected;
  final ValueChanged<RelationshipRankingPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: RelationshipRankingPeriod.values.map((period) {
        final isSelected = selected == period;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => onChanged(period),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: isSelected ? const Color(0xFFFF5AAA) : Colors.white.withValues(alpha: 0.08),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: Text(
                  period.label,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF230B1E) : Colors.white.withValues(alpha: 0.76),
                    fontSize: 11.5,
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
    required this.period,
    required this.count,
    required this.loading,
    required this.error,
    required this.onRefresh,
  });

  final RelationshipRankingPeriod period;
  final int count;
  final bool loading;
  final String? error;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final path = '/relationships/rankings?period=${period.backendValue}';
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
            '$count pairs',
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

class _RelationshipRankTile extends StatelessWidget {
  const _RelationshipRankTile({required this.entry});

  final RelationshipRankingEntry entry;

  @override
  Widget build(BuildContext context) {
    final pair = entry.pair;
    final left = pair.currentUser;
    final right = pair.otherUser;
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
              style: const TextStyle(color: Color(0xFFFF5AAA), fontSize: 13, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 8),
          _PairAvatars(left: left, right: right),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${left?.displayName ?? 'Vibe User'} ❤ ${right?.displayName ?? 'Vibe User'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  'Bond Lv.${pair.level} · ${_compact(pair.totalExp)} total EXP',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.52),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _compact(entry.score),
            style: const TextStyle(color: Color(0xFFFF5AAA), fontSize: 13, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _PairAvatars extends StatelessWidget {
  const _PairAvatars({required this.left, required this.right});

  final RelationshipPairUser? left;
  final RelationshipPairUser? right;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 38,
      child: Stack(
        children: [
          Positioned(left: 0, child: _Avatar(user: left)),
          Positioned(right: 0, child: _Avatar(user: right)),
          Positioned.fill(
            child: Center(
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFF5AAA),
                ),
                child: const Icon(Icons.favorite_rounded, size: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user});

  final RelationshipPairUser? user;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user?.avatarUrl;
    return CircleAvatar(
      radius: 19,
      backgroundColor: const Color(0xFFFF5AAA).withValues(alpha: 0.24),
      backgroundImage: avatarUrl == null ? null : NetworkImage(avatarUrl),
      child: avatarUrl == null
          ? Text(
              _initial(user?.displayName ?? 'V'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
            )
          : null,
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
          Icon(Icons.favorite_border_rounded, color: Colors.white.withValues(alpha: 0.56), size: 38),
          const SizedBox(height: 10),
          Text(
            error == null ? 'No relationship rankings yet' : 'Could not load relationship rankings',
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
