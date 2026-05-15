import 'dart:async';

import 'package:flutter/material.dart';

import '../data/coin_game_rankings_api_service.dart';

class CoinGameRankingsSheet extends StatefulWidget {
  const CoinGameRankingsSheet({
    super.key,
    this.initialGameId,
    this.initialType = CoinGameRankingType.winnings,
    this.initialPeriod = CoinGameRankingPeriod.daily,
  });

  final String? initialGameId;
  final CoinGameRankingType initialType;
  final CoinGameRankingPeriod initialPeriod;

  static Future<void> show(
    BuildContext context, {
    String? initialGameId,
    CoinGameRankingType initialType = CoinGameRankingType.winnings,
    CoinGameRankingPeriod initialPeriod = CoinGameRankingPeriod.daily,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CoinGameRankingsSheet(
        initialGameId: initialGameId,
        initialType: initialType,
        initialPeriod: initialPeriod,
      ),
    );
  }

  @override
  State<CoinGameRankingsSheet> createState() => _CoinGameRankingsSheetState();
}

class _CoinGameRankingsSheetState extends State<CoinGameRankingsSheet> {
  final CoinGameRankingsApiService _api = const CoinGameRankingsApiService();

  late CoinGameRankingType _type = widget.initialType;
  late CoinGameRankingPeriod _period = widget.initialPeriod;
  List<CoinGameInfo> _games = const <CoinGameInfo>[];
  String? _selectedGameId;
  List<CoinGameRankingEntry> _entries = const <CoinGameRankingEntry>[];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedGameId = widget.initialGameId;
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
      final games = _games.isEmpty ? await _api.getGames() : _games;
      final selectedGameId = _selectedGameId?.trim().isNotEmpty == true
          ? _selectedGameId!.trim()
          : (games.isNotEmpty ? games.first.id : 'crystal-hunt');
      final entries = await _api.getRankings(
        gameId: selectedGameId,
        type: _type,
        period: _period,
        limit: 100,
      );
      if (!mounted) return;
      setState(() {
        _games = games;
        _selectedGameId = selectedGameId;
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

  void _changeType(CoinGameRankingType type) {
    if (_type == type) return;
    setState(() {
      _type = type;
      _entries = const <CoinGameRankingEntry>[];
      _error = null;
    });
    unawaited(_load());
  }

  void _changePeriod(CoinGameRankingPeriod period) {
    if (_period == period) return;
    setState(() {
      _period = period;
      _entries = const <CoinGameRankingEntry>[];
      _error = null;
    });
    unawaited(_load());
  }

  void _changeGame(String gameId) {
    if (_selectedGameId == gameId) return;
    setState(() {
      _selectedGameId = gameId;
      _entries = const <CoinGameRankingEntry>[];
      _error = null;
    });
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final gameName = _games
        .where((game) => game.id == _selectedGameId)
        .map((game) => game.name)
        .firstOrNull ??
        (_selectedGameId ?? 'Coin Game');

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.84,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF101021), Color(0xFF26124B), Color(0xFF3A1E09)],
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
                _Header(gameName: gameName, onClose: () => Navigator.pop(context)),
                const SizedBox(height: 12),
                if (_games.isNotEmpty) _GameTabs(games: _games, selectedGameId: _selectedGameId, onChanged: _changeGame),
                if (_games.isNotEmpty) const SizedBox(height: 10),
                _TypeTabs(selected: _type, onChanged: _changeType),
                const SizedBox(height: 10),
                _PeriodTabs(selected: _period, onChanged: _changePeriod),
                const SizedBox(height: 12),
                _StatusPill(
                  gameId: _selectedGameId ?? 'crystal-hunt',
                  type: _type,
                  period: _period,
                  count: _entries.length,
                  loading: _loading,
                  error: _error,
                  onRefresh: () => unawaited(_load()),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _loading && _entries.isEmpty
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFC857)))
                      : _entries.isEmpty
                          ? _EmptyState(error: _error, onRetry: () => unawaited(_load()))
                          : RefreshIndicator(
                              onRefresh: _load,
                              color: const Color(0xFFFFC857),
                              child: ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                padding: const EdgeInsets.only(bottom: 12),
                                itemCount: _entries.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 8),
                                itemBuilder: (context, index) => _RankingTile(entry: _entries[index], type: _type),
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
  const _Header({required this.gameName, required this.onClose});

  final String gameName;
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
          child: const Icon(Icons.casino_rounded, color: Color(0xFFFFC857), size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(gameName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
              Text('Coin game rankings and activity', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.58), fontSize: 11.5, fontWeight: FontWeight.w800)),
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
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.10), border: Border.all(color: Colors.white.withValues(alpha: 0.14))),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
            ),
          ),
        ),
      ],
    );
  }
}

class _GameTabs extends StatelessWidget {
  const _GameTabs({required this.games, required this.selectedGameId, required this.onChanged});

  final List<CoinGameInfo> games;
  final String? selectedGameId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: games.length,
        separatorBuilder: (context, index) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final game = games[index];
          final selected = selectedGameId == game.id;
          return GestureDetector(
            onTap: () => onChanged(game.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: selected ? const Color(0xFFFFC857) : Colors.white.withValues(alpha: 0.08),
                border: Border.all(color: selected ? Colors.white.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.10)),
              ),
              child: Text(game.name, style: TextStyle(color: selected ? const Color(0xFF101021) : Colors.white.withValues(alpha: 0.78), fontSize: 11.5, fontWeight: FontWeight.w900)),
            ),
          );
        },
      ),
    );
  }
}

class _TypeTabs extends StatelessWidget {
  const _TypeTabs({required this.selected, required this.onChanged});

  final CoinGameRankingType selected;
  final ValueChanged<CoinGameRankingType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: CoinGameRankingType.values.map((type) {
        final selectedItem = selected == type;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => onChanged(type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: selectedItem ? const Color(0xFFFFC857) : Colors.white.withValues(alpha: 0.08),
                  border: Border.all(color: selectedItem ? Colors.white.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.10)),
                ),
                child: Text(type.label, style: TextStyle(color: selectedItem ? const Color(0xFF101021) : Colors.white.withValues(alpha: 0.76), fontSize: 11.5, fontWeight: FontWeight.w900)),
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

  final CoinGameRankingPeriod selected;
  final ValueChanged<CoinGameRankingPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: CoinGameRankingPeriod.values.map((period) {
        final selectedItem = selected == period;
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
                  color: selectedItem ? Colors.white.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.06),
                  border: Border.all(color: selectedItem ? Colors.white.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.08)),
                ),
                child: Text(period.label, style: TextStyle(color: selectedItem ? Colors.white : Colors.white.withValues(alpha: 0.62), fontSize: 10.5, fontWeight: FontWeight.w900)),
              ),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.gameId, required this.type, required this.period, required this.count, required this.loading, required this.error, required this.onRefresh});

  final String gameId;
  final CoinGameRankingType type;
  final CoinGameRankingPeriod period;
  final int count;
  final bool loading;
  final String? error;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final path = '/games/$gameId/rankings/${type.backendValue}?period=${period.backendValue}';
    final status = loading ? 'syncing live...' : error == null ? 'live backend data' : 'fallback: $error';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.10))),
      child: Row(
        children: [
          const Icon(Icons.query_stats_rounded, color: Color(0xFFFFC857), size: 16),
          const SizedBox(width: 7),
          Expanded(child: Text('$status · GET $path', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.54), fontSize: 10.5, fontWeight: FontWeight.w800))),
          Text('$count ranks', style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontSize: 10.5, fontWeight: FontWeight.w900)),
          const SizedBox(width: 6),
          GestureDetector(onTap: onRefresh, child: Icon(Icons.refresh_rounded, color: Colors.white.withValues(alpha: 0.75), size: 17)),
        ],
      ),
    );
  }
}

class _RankingTile extends StatelessWidget {
  const _RankingTile({required this.entry, required this.type});

  final CoinGameRankingEntry entry;
  final CoinGameRankingType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withValues(alpha: 0.10))),
      child: Row(
        children: [
          SizedBox(width: 34, child: Text('#${entry.rank}', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFFC857), fontSize: 13, fontWeight: FontWeight.w900))),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 21,
            backgroundColor: const Color(0xFFFFC857).withValues(alpha: 0.22),
            backgroundImage: entry.avatarUrl == null ? null : NetworkImage(entry.avatarUrl!),
            child: entry.avatarUrl == null ? Text(_initial(entry.displayName), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)) : null,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(entry.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900))),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_compact(entry.score), style: const TextStyle(color: Color(0xFFFFC857), fontSize: 13, fontWeight: FontWeight.w900)),
              Text('${entry.rounds} rounds · ${type.label}', style: TextStyle(color: Colors.white.withValues(alpha: 0.42), fontSize: 9.5, fontWeight: FontWeight.w800)),
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
          Icon(Icons.casino_outlined, color: Colors.white.withValues(alpha: 0.56), size: 38),
          const SizedBox(height: 10),
          Text(error == null ? 'No coin game rankings yet' : 'Could not load coin game rankings', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
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
