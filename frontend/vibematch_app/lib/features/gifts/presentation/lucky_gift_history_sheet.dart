import 'dart:async';

import 'package:flutter/material.dart';

import '../data/lucky_gifts_api_service.dart';

class LuckyGiftHistorySheet extends StatefulWidget {
  const LuckyGiftHistorySheet({
    super.key,
    this.initialPeriod = LuckyGiftPeriod.daily,
  });

  final LuckyGiftPeriod initialPeriod;

  static Future<void> show(
    BuildContext context, {
    LuckyGiftPeriod initialPeriod = LuckyGiftPeriod.daily,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LuckyGiftHistorySheet(initialPeriod: initialPeriod),
    );
  }

  @override
  State<LuckyGiftHistorySheet> createState() => _LuckyGiftHistorySheetState();
}

class _LuckyGiftHistorySheetState extends State<LuckyGiftHistorySheet> {
  final LuckyGiftsApiService _api = const LuckyGiftsApiService();

  late LuckyGiftPeriod _period = widget.initialPeriod;
  List<LuckyGiftHistoryEntry> _history = const <LuckyGiftHistoryEntry>[];
  LuckyGiftMaster? _master;
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
        _api.getHistory(period: _period, limit: 100),
        _api.getMaster(),
      ]);
      if (!mounted) return;
      setState(() {
        _history = results[0] as List<LuckyGiftHistoryEntry>;
        _master = results[1] as LuckyGiftMaster;
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

  void _changePeriod(LuckyGiftPeriod period) {
    if (_period == period) return;
    setState(() {
      _period = period;
      _history = const <LuckyGiftHistoryEntry>[];
      _error = null;
    });
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final master = _master;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.84,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF160B28), Color(0xFF32134E), Color(0xFF4A240A)],
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
                _MasterPreview(master: master),
                const SizedBox(height: 12),
                _StatusPill(
                  period: _period,
                  count: _history.length,
                  loading: _loading,
                  error: _error,
                  onRefresh: () => unawaited(_load()),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _loading && _history.isEmpty
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFC857)))
                      : _history.isEmpty
                          ? _EmptyState(error: _error, onRetry: () => unawaited(_load()))
                          : RefreshIndicator(
                              onRefresh: _load,
                              color: const Color(0xFFFFC857),
                              child: ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                padding: const EdgeInsets.only(bottom: 12),
                                itemCount: _history.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 8),
                                itemBuilder: (context, index) => _HistoryTile(entry: _history[index]),
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
          child: const Icon(Icons.history_rounded, color: Color(0xFFFFC857), size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lucky Gift History',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.4),
              ),
              Text(
                'Winnings, multipliers, and net results',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.58), fontSize: 11.5, fontWeight: FontWeight.w800),
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
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: isSelected ? const Color(0xFFFFC857) : Colors.white.withValues(alpha: 0.08),
                  border: Border.all(color: isSelected ? Colors.white.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.10)),
                ),
                child: Text(
                  period.label,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF160B28) : Colors.white.withValues(alpha: 0.76),
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

class _MasterPreview extends StatelessWidget {
  const _MasterPreview({required this.master});

  final LuckyGiftMaster? master;

  @override
  Widget build(BuildContext context) {
    final multipliers = master?.multipliers.map((rule) => '${rule.multiplier}x').take(8).join(' · ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          const Icon(Icons.casino_rounded, color: Color(0xFFFFC857), size: 16),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              master == null
                  ? 'Lucky gift master config loading...'
                  : '${master.enabled ? 'Enabled' : 'Disabled'} · ${master.currency} · ${multipliers?.isEmpty == false ? multipliers : 'no multiplier rules'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.period, required this.count, required this.loading, required this.error, required this.onRefresh});

  final LuckyGiftPeriod period;
  final int count;
  final bool loading;
  final String? error;
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
          const Icon(Icons.query_stats_rounded, color: Color(0xFFFFC857), size: 16),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              '$status · GET /lucky-gifts/history?period=${period.backendValue}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.54), fontSize: 10.5, fontWeight: FontWeight.w800),
            ),
          ),
          Text('$count logs', style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontSize: 10.5, fontWeight: FontWeight.w900)),
          const SizedBox(width: 6),
          GestureDetector(onTap: onRefresh, child: Icon(Icons.refresh_rounded, color: Colors.white.withValues(alpha: 0.75), size: 17)),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final LuckyGiftHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final netWinPositive = entry.netWinCoins >= 0;
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
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFC857).withValues(alpha: 0.16),
              border: Border.all(color: const Color(0xFFFFC857).withValues(alpha: 0.24)),
            ),
            child: Center(
              child: Text('${entry.multiplier}x', style: const TextStyle(color: Color(0xFFFFC857), fontSize: 11, fontWeight: FontWeight.w900)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.giftName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text('Spent ${_compact(entry.spentCoins)} · Won ${_compact(entry.rewardCoins)} · ${_dateLabel(entry.createdAt)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.46), fontSize: 10.5, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${netWinPositive ? '+' : ''}${_compact(entry.netWinCoins)}',
            style: TextStyle(color: netWinPositive ? const Color(0xFFFFC857) : Colors.white.withValues(alpha: 0.55), fontSize: 12.5, fontWeight: FontWeight.w900),
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
          Icon(Icons.history_toggle_off_rounded, color: Colors.white.withValues(alpha: 0.56), size: 38),
          const SizedBox(height: 10),
          Text(error == null ? 'No lucky gift history yet' : 'Could not load lucky gift history', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

String _compact(int value) {
  final sign = value < 0 ? '-' : '';
  final absValue = value.abs();
  if (absValue >= 1000000000) return '$sign${(absValue / 1000000000).toStringAsFixed(1)}B';
  if (absValue >= 1000000) return '$sign${(absValue / 1000000).toStringAsFixed(1)}M';
  if (absValue >= 1000) return '$sign${(absValue / 1000).toStringAsFixed(1)}K';
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
