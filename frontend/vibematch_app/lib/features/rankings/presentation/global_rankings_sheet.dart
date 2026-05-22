import 'dart:async';

import 'package:flutter/material.dart';

import '../../rooms/presentation/widgets/chat_vip_badge.dart';
import '../data/global_rankings_api_service.dart';

class GlobalRankingsSheet extends StatefulWidget {
  const GlobalRankingsSheet({
    super.key,
    this.initialType = GlobalRankingType.sent,
    this.initialPeriod = GlobalRankingPeriod.daily,
  });

  final GlobalRankingType initialType;
  final GlobalRankingPeriod initialPeriod;

  static Future<void> show(
    BuildContext context, {
    GlobalRankingType initialType = GlobalRankingType.sent,
    GlobalRankingPeriod initialPeriod = GlobalRankingPeriod.daily,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GlobalRankingsSheet(
        initialType: initialType,
        initialPeriod: initialPeriod,
      ),
    );
  }

  @override
  State<GlobalRankingsSheet> createState() => _GlobalRankingsSheetState();
}

class _GlobalRankingsSheetState extends State<GlobalRankingsSheet> {
  final GlobalRankingsApiService _api = const GlobalRankingsApiService();

  late GlobalRankingType _type = widget.initialType;
  late GlobalRankingPeriod _period = widget.initialPeriod;
  GlobalRankingResponse? _response;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final response = await _api.fetchRanking(
        type: _type,
        period: _period,
        limit: 100,
      );
      if (!mounted) return;
      setState(() {
        _response = response;
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

  void _changeType(GlobalRankingType type) {
    if (_type == type) return;
    setState(() {
      _type = type;
      _response = null;
      _error = null;
    });
    unawaited(_load());
  }

  void _changePeriod(GlobalRankingPeriod period) {
    if (_period == period) return;
    setState(() {
      _period = period;
      _response = null;
      _error = null;
    });
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final entries = _response?.entries ?? const <GlobalRankingEntry>[];
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.82,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF170B24), Color(0xFF2B1740), Color(0xFF0E2D35)],
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
                _Header(type: _type, onClose: () => Navigator.pop(context)),
                const SizedBox(height: 12),
                _TypeTabs(selected: _type, onChanged: _changeType),
                const SizedBox(height: 10),
                _PeriodTabs(selected: _period, onChanged: _changePeriod),
                const SizedBox(height: 12),
                Expanded(
                  child: _loading && entries.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(color: Color(0xFF12C7B7)),
                        )
                      : entries.isEmpty
                          ? _EmptyState(error: _error, onRetry: () => unawaited(_load()))
                          : RefreshIndicator(
                              onRefresh: _load,
                              color: const Color(0xFF12C7B7),
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
  const _Header({required this.type, required this.onClose});

  final GlobalRankingType type;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _accent(type).withValues(alpha: 0.18),
            border: Border.all(color: _accent(type).withValues(alpha: 0.42)),
          ),
          child: Icon(_icon(type), color: _accent(type), size: 21),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Global Rankings',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
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

class _TypeTabs extends StatelessWidget {
  const _TypeTabs({required this.selected, required this.onChanged});

  final GlobalRankingType selected;
  final ValueChanged<GlobalRankingType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: GlobalRankingType.values.map((type) {
        final isSelected = selected == type;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => onChanged(type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: isSelected ? _accent(type) : Colors.white.withValues(alpha: 0.08),
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
            ),
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({required this.selected, required this.onChanged});

  final GlobalRankingPeriod selected;
  final ValueChanged<GlobalRankingPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: GlobalRankingPeriod.values.map((period) {
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
                    fontSize: 11,
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

class _RankingTile extends StatelessWidget {
  const _RankingTile({required this.entry, required this.type});

  final GlobalRankingEntry entry;
  final GlobalRankingType type;

  @override
  Widget build(BuildContext context) {
    final accent = _accent(type);
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
              style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 21,
            backgroundColor: accent.withValues(alpha: 0.22),
            backgroundImage: entry.user.avatarUrl == null ? null : NetworkImage(entry.user.avatarUrl!),
            child: entry.user.avatarUrl == null
                ? Text(
                    _initial(entry.user.displayName),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    entry.user.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 5),
                ChatVipBadge(level: entry.user.vipLevel, showWhenZero: true),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                entry.scoreDisplay,
                style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w900),
              ),
              Text(
                type == GlobalRankingType.recharge ? 'coins' : 'gift coins',
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
          Icon(Icons.emoji_events_outlined, color: Colors.white.withValues(alpha: 0.56), size: 38),
          const SizedBox(height: 10),
          Text(
            error == null ? 'No ranking data yet' : 'Could not load rankings',
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

Color _accent(GlobalRankingType type) {
  switch (type) {
    case GlobalRankingType.sent:
      return const Color(0xFFFFC857);
    case GlobalRankingType.received:
      return const Color(0xFF12C7B7);
    case GlobalRankingType.recharge:
      return const Color(0xFFE84C72);
  }
}

IconData _icon(GlobalRankingType type) {
  switch (type) {
    case GlobalRankingType.sent:
      return Icons.north_east_rounded;
    case GlobalRankingType.received:
      return Icons.south_west_rounded;
    case GlobalRankingType.recharge:
      return Icons.diamond_rounded;
  }
}

String _initial(String name) {
  final text = name.trim();
  if (text.isEmpty) return 'V';
  return text.characters.first.toUpperCase();
}