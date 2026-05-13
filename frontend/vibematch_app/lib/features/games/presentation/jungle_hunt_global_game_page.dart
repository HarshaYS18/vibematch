import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/game_api_service.dart';
import '../data/jungle_hunt_history_api.dart';
import 'widgets/jungle_hunt_basket_strip.dart';

class JungleHuntGlobalGamePage extends StatefulWidget {
  const JungleHuntGlobalGamePage({super.key, this.embeddedInRoom = false});

  final bool embeddedInRoom;

  @override
  State<JungleHuntGlobalGamePage> createState() => _JungleHuntGlobalGamePageState();
}

enum _JunglePhase { loading, betting, locked, revealing, result }

class _JungleHuntGlobalGamePageState extends State<JungleHuntGlobalGamePage> {
  final GameApiService _api = const GameApiService();
  final JungleHuntHistoryApi _historyApi = const JungleHuntHistoryApi();
  final Map<int, int> _placedByTarget = <int, int>{};
  final List<_HistoryItem> _history = <_HistoryItem>[];

  Timer? _clockTimer;
  Timer? _spinTimer;
  Timer? _overlayTimer;
  GameDefinition? _game;
  GameRound? _round;
  GameRoundResult? _result;
  int? _coinBalance;
  int _selectedTargetId = 0;
  int _selectedAmount = 10000;
  int _secondsLeft = 0;
  int _revealIndex = 0;
  bool _loading = false;
  bool _showResultOverlay = false;
  String? _error;
  _JunglePhase _phase = _JunglePhase.loading;

  bool get _isBettingOpen => _round != null && _phase == _JunglePhase.betting && _secondsLeft > 2 && !_loading;
  bool get _didBet => _placedByTarget.values.fold<int>(0, (sum, item) => sum + item) > 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadHistory());
    unawaited(_joinGlobalRound());
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _spinTimer?.cancel();
    _overlayTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final items = await _historyApi.loadHistory(limit: 30);
      if (!mounted) return;

      setState(() {
        _history
          ..clear()
          ..addAll(
            items.map(
              (item) => _HistoryItem(
                target: _targetForHistoryId(item.winningTargetId),
                roundId: item.roundId,
              ),
            ),
          );
      });
    } catch (_) {
      // History is non-blocking. If backend is unavailable, keep local/fallback history.
    }
  }
  Future<void> _joinGlobalRound() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _phase = _JunglePhase.loading;
    });

    try {
      var games = await _api.loadCatalog();
      if (games.isEmpty) games = <GameDefinition>[await _api.seedDefaultGames()];
      final enabled = games.where((game) => game.isEnabled).toList();
      final list = enabled.isEmpty ? games : enabled;
      final game = list.firstWhere(
        (item) => item.gameKey == 'jungle_hunt' || item.gameKey == 'jackpot_king',
        orElse: () => list.first,
      );
      final round = await _api.createRound(gameKey: game.gameKey);
      if (!mounted) return;
      setState(() {
        _game = game;
        _round = round;
        _result = null;
        _showResultOverlay = false;
        _placedByTarget.clear();
        _selectedTargetId = _targets.first.id;
        _selectedAmount = _amounts.first;
      });
      _applyServerPhaseAndStart(round);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyServerPhaseAndStart(GameRound round) {
    _clockTimer?.cancel();
    _spinTimer?.cancel();

    final metadata = round.metadata;
    final phase = metadata['phase']?.toString().toUpperCase();
    final bettingLeft = _int(metadata['betting_seconds_left']);
    final revealLeft = _int(metadata['reveal_seconds_left']);

    if (phase == 'REVEALING') {
      setState(() {
        _phase = _JunglePhase.revealing;
        _secondsLeft = revealLeft > 0 ? revealLeft : 15;
        _revealIndex = 0;
      });
      unawaited(_beginReveal(totalMs: (_secondsLeft * 200).clamp(1200, 3000)));
      return;
    }

    if (phase == 'RESULT') {
      setState(() {
        _phase = _JunglePhase.result;
        _secondsLeft = 3;
      });
      unawaited(_beginReveal(totalMs: 1500));
      return;
    }

    setState(() {
      if (phase == 'LOCKED' || bettingLeft <= 2) {
        _phase = _JunglePhase.locked;
        _secondsLeft = 2;
      } else {
        _phase = _JunglePhase.betting;
        _secondsLeft = bettingLeft > 0 ? bettingLeft : 30;
      }
    });
    _startBetLockClock();
  }

  void _startBetLockClock() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_phase == _JunglePhase.betting) {
        if (_secondsLeft <= 3) {
          setState(() {
            _phase = _JunglePhase.locked;
            _secondsLeft = 2;
          });
        } else {
          setState(() => _secondsLeft -= 1);
        }
        return;
      }

      if (_phase == _JunglePhase.locked) {
        if (_secondsLeft <= 1) {
          timer.cancel();
          setState(() {
            _phase = _JunglePhase.revealing;
            _secondsLeft = 15;
            _revealIndex = 0;
          });
          unawaited(_beginReveal(totalMs: 3000));
        } else {
          setState(() => _secondsLeft -= 1);
        }
      }
    });
  }

  Future<void> _beginReveal({required int totalMs}) async {
    final round = _round;
    if (round == null) return;

    GameRoundResult result;
    try {
      result = await _api.settleTestRound(round.id);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
      return;
    }
    if (!mounted) return;

    final winnerIndex = _targets.indexWhere((target) => target.id == result.winningTargetId);
    final safeWinnerIndex = winnerIndex < 0 ? 0 : winnerIndex;
    final delays = _spinDelays(totalMs: totalMs, startIndex: _revealIndex, winnerIndex: safeWinnerIndex);
    var step = 0;
    var elapsedMs = 0;

    void nextSpin() {
      if (!mounted) return;
      if (step >= delays.length) {
        _finishReveal(result, safeWinnerIndex);
        return;
      }

      final delay = delays[step];
      _spinTimer = Timer(Duration(milliseconds: delay), () {
        if (!mounted) return;
        elapsedMs += delay;
        setState(() {
          _revealIndex = (_revealIndex + 1) % _targets.length;
          _secondsLeft = math.max(((totalMs - elapsedMs) / 1000).ceil(), 0);
        });
        step += 1;
        nextSpin();
      });
    }

    nextSpin();
  }

  List<int> _spinDelays({required int totalMs, required int startIndex, required int winnerIndex}) {
    const baseLoops = 7;
    final afterLoopsIndex = (startIndex + (baseLoops * _targets.length)) % _targets.length;
    final delta = (winnerIndex - afterLoopsIndex) % _targets.length;
    final steps = (baseLoops * _targets.length) + delta;
    final weights = <double>[];

    for (var i = 0; i < steps; i++) {
      final p = steps <= 1 ? 1.0 : i / (steps - 1);
      if (p < 0.20) {
        weights.add(2.4 - (1.65 * (p / 0.20))); // slow start, speeds up
      } else if (p < 0.62) {
        weights.add(0.42); // very fast middle
      } else {
        final q = (p - 0.62) / 0.38;
        weights.add(0.55 + (3.1 * q * q)); // slow down strongly
      }
    }

    final totalWeight = weights.fold<double>(0, (sum, item) => sum + item);
    return weights.map((weight) => math.max(38, (totalMs * weight / totalWeight).round())).toList(growable: false);
  }

  void _finishReveal(GameRoundResult result, int winnerIndex) {
    final winner = _targets[winnerIndex];
    setState(() {
      _result = result;
      _phase = _JunglePhase.result;
      _secondsLeft = 3;
      _revealIndex = winnerIndex;
      _coinBalance = result.walletCoinBalance;
      _history.insert(0, _HistoryItem(target: winner, roundId: result.roundId));
      if (_history.length > 30) _history.removeLast();
      _showResultOverlay = true;
    });

    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _showResultOverlay = false);
      unawaited(_joinGlobalRound());
    });
  }

  Future<void> _placeOn(_JungleTarget target) async {
    final round = _round;
    if (round == null) return;
    if (!_isBettingOpen) {
      _showToast('Betting is locked for this phase.');
      return;
    }
    setState(() => _selectedTargetId = target.id);

    try {
      final result = await _api.placeBet(
        roundId: round.id,
        targetId: target.id,
        amount: _selectedAmount,
      );
      if (!mounted) return;
      setState(() => _coinBalance = result.walletCoinBalance);
      if (result.acceptedAmount <= 0) {
        _showToast(result.message.isEmpty ? 'Bet rejected by game safety.' : result.message);
        return;
      }
      setState(() {
        _placedByTarget[target.id] = (_placedByTarget[target.id] ?? 0) + result.acceptedAmount;
      });
    } catch (error) {
      if (!mounted) return;
      _showToast(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.w900)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF2D1809),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(widget.embeddedInRoom ? 26 : 0)),
      child: Scaffold(
        backgroundColor: const Color(0xFF06140B),
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/games/jungle_hunt/backgrounds/bg_jungle_hunt.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF0B3B25), Color(0xFF041109), Color(0xFF2E1809)],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.22))),
            SafeArea(
              top: !widget.embeddedInRoom,
              child: Column(
                children: [
                  _Header(
                    roundId: _round?.id,
                    coinBalance: _coinBalance,
                    history: _history,
                    phase: _phase,
                    onClose: () => Navigator.pop(context),
                  ),
                  if (_error != null) _ErrorStrip(message: _error!, onRetry: _joinGlobalRound),
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _TargetWheel(
                          targets: _targets,
                          selectedId: _selectedTargetId,
                          winnerId: _result?.winningTargetId,
                          placedByTarget: _placedByTarget,
                          isOpen: _isBettingOpen,
                          revealIndex: _phase == _JunglePhase.revealing || _phase == _JunglePhase.result ? _revealIndex : null,
                          onTap: _placeOn,
                        ),
                        _CenterStatus(phase: _phase, secondsLeft: _secondsLeft, loading: _loading),
                      ],
                    ),
                  ),
                  JungleHuntBasketStrip(
                    leftHighlighted: _result?.winningTargetId == 100,
                    rightHighlighted: _result?.winningTargetId == 101,
                    assetForId: (id) => _targets.firstWhere((target) => target.id == id).asset,
                  ),                  _BottomPanel(
                    amounts: _amounts,
                    selectedAmount: _selectedAmount,
                    totalPlaced: _placedByTarget.values.fold<int>(0, (sum, item) => sum + item),
                    enabled: _phase == _JunglePhase.betting,
                    onAmount: (amount) => setState(() => _selectedAmount = amount),
                  ),
                ],
              ),
            ),
            if (_showResultOverlay && _result != null)
              Positioned.fill(
                child: _ResultOverlay(
                  result: _result!,
                  didBet: _didBet,
                  topWinners: _topWinners(_result!),
                ),
              ),
            if (_showResultOverlay && _result != null)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 78,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: _WinningItemImage(
                    target: _targetForHistoryId(_result!.winningTargetId),
                  ),
                ),
              ),
            if (_loading && _phase == _JunglePhase.loading)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.10),
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(color: Color(0xFFFFD36A), strokeWidth: 2.4),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<_RoundWinner> _topWinners(GameRoundResult result) {
    if (result.topWinners.isNotEmpty) {
      return result.topWinners
          .take(3)
          .map((winner) => _RoundWinner(name: winner.name, avatar: winner.avatar, coins: winner.coins))
          .toList(growable: false);
    }
    final base = math.max(result.totalUserWinnings, result.multiplier * 10000);
    return <_RoundWinner>[
      _RoundWinner(name: 'Top 1', avatar: '👑', coins: base + 120000),
      _RoundWinner(name: 'Top 2', avatar: '🔥', coins: (base * 0.72).round()),
      _RoundWinner(name: 'Top 3', avatar: '⭐', coins: (base * 0.46).round()),
    ];
  }
}

class _WinningItemImage extends StatelessWidget {
  const _WinningItemImage({required this.target});

  final _JungleTarget target;

  @override
  Widget build(BuildContext context) {
    final hasAsset = target.asset.trim().isNotEmpty;

    return Center(
      child: Container(
        width: 82,
        height: 82,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const SweepGradient(
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFFFF176),
              Color(0xFFFF8F00),
              Color(0xFFFFFFFF),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFC857).withValues(alpha: 0.68),
              blurRadius: 28,
              spreadRadius: 4,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.42),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipOval(
          child: Container(
            color: const Color(0xFF2A1306),
            child: hasAsset
                ? Image.asset(
                    target.asset,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Text(target.emoji, style: const TextStyle(fontSize: 38)),
                    ),
                  )
                : Center(
                    child: Text(target.emoji, style: const TextStyle(fontSize: 38)),
                  ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.roundId, required this.coinBalance, required this.history, required this.phase, required this.onClose});

  final int? roundId;
  final int? coinBalance;
  final List<_HistoryItem> history;
  final _JunglePhase phase;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 6),
      child: Column(
        children: [
          Row(
            children: [
              const Text('🦁', style: TextStyle(fontSize: 30)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Jungle Hunt', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(roundId == null ? _phaseLabel(phase) : 'Round #$roundId', style: TextStyle(color: Colors.white.withValues(alpha: 0.74), fontSize: 11, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.26),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFFFD36A).withValues(alpha: 0.52)),
                    ),
                    child: Text('🪙 ${coinBalance == null ? '--' : _compact(coinBalance!)}', style: const TextStyle(color: Color(0xFFFFD36A), fontSize: 11, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded, color: Colors.white, size: 27)),
            ],
          ),
          const SizedBox(height: 7),
          _HistoryPill(history: history),
        ],
      ),
    );
  }
}

class _HistoryPill extends StatelessWidget {
  const _HistoryPill({required this.history});

  final List<_HistoryItem> history;

  @override
  Widget build(BuildContext context) {
    final items = history.isEmpty ? _targets.take(8).map((target) => _HistoryItem(target: target, roundId: 0)).toList() : history.take(30).toList();
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          const Icon(Icons.sticky_note_2_rounded, color: Color(0xFFFFD36A), size: 16),
          const SizedBox(width: 5),
          Text('Previous', style: TextStyle(color: Colors.white.withValues(alpha: 0.80), fontSize: 11, fontWeight: FontWeight.w900)),
          const SizedBox(width: 8),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(width: 5),
              itemBuilder: (context, index) => _MiniAnimalDot(target: items[index].target),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniAnimalDot extends StatelessWidget {
  const _MiniAnimalDot({required this.target});

  final _JungleTarget target;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF2A1306),
        border: Border.all(color: const Color(0xFFFFD36A).withValues(alpha: 0.66)),
      ),
      child: ClipOval(
        child: Image.asset(
          target.asset,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Center(child: Text(target.emoji, style: const TextStyle(fontSize: 12))),
        ),
      ),
    );
  }
}

class _TargetWheel extends StatelessWidget {
  const _TargetWheel({required this.targets, required this.selectedId, required this.winnerId, required this.placedByTarget, required this.isOpen, required this.revealIndex, required this.onTap});

  final List<_JungleTarget> targets;
  final int? selectedId;
  final int? winnerId;
  final Map<int, int> placedByTarget;
  final bool isOpen;
  final int? revealIndex;
  final ValueChanged<_JungleTarget> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final shortest = math.min(constraints.maxWidth, constraints.maxHeight);
        final radius = (shortest * 0.31).clamp(96.0, 148.0);
        final item = (shortest * 0.22).clamp(72.0, 98.0);
        final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
        return Stack(
          children: [
            Center(
              child: Container(
                width: radius * 2.20,
                height: radius * 2.20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4A260C).withValues(alpha: 0.76),
                  border: Border.all(color: const Color(0xFFFFC557), width: 7),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.30), blurRadius: 18, offset: const Offset(0, 10))],
                ),
              ),
            ),
            for (var i = 0; i < targets.length; i++)
              Positioned(
                left: center.dx + math.cos(-math.pi / 2 + math.pi * 2 * i / targets.length) * radius - item / 2,
                top: center.dy + math.sin(-math.pi / 2 + math.pi * 2 * i / targets.length) * radius - item / 2,
                width: item,
                height: item,
                child: _TargetTile(
                  target: targets[i],
                  selected: selectedId == targets[i].id,
                  winner: winnerId == targets[i].id,
                  revealing: revealIndex == i,
                  placed: placedByTarget[targets[i].id] ?? 0,
                  enabled: isOpen,
                  onTap: () => onTap(targets[i]),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TargetTile extends StatelessWidget {
  const _TargetTile({required this.target, required this.selected, required this.winner, required this.revealing, required this.placed, required this.enabled, required this.onTap});

  final _JungleTarget target;
  final bool selected;
  final bool winner;
  final bool revealing;
  final int placed;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final highlighted = winner || selected || revealing;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedScale(
        scale: winner ? 1.17 : revealing ? 1.12 : selected ? 1.06 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 110),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: highlighted
                      ? const [Color(0xFFFFFFFF), Color(0xFFFFF176), Color(0xFFFF8F00), Color(0xFFFFFFFF)]
                      : const [Color(0xFFFFD36A), Color(0xFF7B3E11), Color(0xFFFFD36A)],
                ),
                boxShadow: highlighted ? [BoxShadow(color: const Color(0xFFFFD36A).withValues(alpha: 0.58), blurRadius: 22, spreadRadius: 1)] : null,
              ),
              padding: const EdgeInsets.all(4),
              child: ClipOval(
                child: Image.asset(
                  target.asset,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Center(child: Text(target.emoji, style: const TextStyle(fontSize: 32))),
                ),
              ),
            ),
            Positioned(
              bottom: 2,
              child: Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [Color(0xFFFFF6A5), Color(0xFFD27617)]),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.72), width: 1.2),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.26), blurRadius: 6)],
                ),
                child: Text('${target.multiplier}x', style: const TextStyle(color: Color(0xFF4A210A), fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ),
            if (placed > 0)
              Positioned(
                top: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.68), borderRadius: BorderRadius.circular(999)),
                  child: Text(_compact(placed), style: const TextStyle(color: Color(0xFFFFD36A), fontSize: 9, fontWeight: FontWeight.w900)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CenterStatus extends StatelessWidget {
  const _CenterStatus({required this.phase, required this.secondsLeft, required this.loading});

  final _JunglePhase phase;
  final int secondsLeft;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final label = _phaseLabel(phase);
    final value = loading && phase == _JunglePhase.loading ? '...' : '${secondsLeft}s';
    return Container(
      width: 116,
      height: 116,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [Color(0xFFFFE8A8), Color(0xFFFF9E2D)]),
        border: Border.all(color: const Color(0xFF71370E), width: 8),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF4A210A), fontSize: 13, fontWeight: FontWeight.w900, height: 1.05)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(color: Color(0xFF4A210A), fontSize: 24, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({required this.amounts, required this.selectedAmount, required this.totalPlaced, required this.enabled, required this.onAmount});

  final List<int> amounts;
  final int selectedAmount;
  final int totalPlaced;
  final bool enabled;
  final ValueChanged<int> onAmount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(10, 9, 10, MediaQuery.paddingOf(context).bottom + 9),
      decoration: BoxDecoration(
        color: const Color(0xFF160B05).withValues(alpha: 0.94),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(top: BorderSide(color: const Color(0xFFFFD36A).withValues(alpha: 0.30))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('🪙', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Expanded(child: Text('This round: ${_money(totalPlaced)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
              if (!enabled) Text('Locked', style: TextStyle(color: Colors.white.withValues(alpha: 0.64), fontSize: 11, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: amounts.map((amount) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _AmountPill(amount: amount, index: amounts.indexOf(amount), selected: amount == selectedAmount, enabled: enabled, onTap: () => onAmount(amount)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _AmountPill extends StatelessWidget {
  const _AmountPill({
    required this.amount,
    required this.index,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final int amount;
  final int index;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = _casinoChipStyles[index % _casinoChipStyles.length];

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: enabled ? 1 : 0.86,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 160),
          scale: selected ? 1.10 : 1,
          child: SizedBox(
            width: 66,
            height: 66,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (selected)
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD36A).withValues(alpha: 0.70),
                          blurRadius: 22,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),
                CustomPaint(
                  size: const Size(62, 62),
                  painter: _CasinoChipPainter(
                    style: style,
                    selected: selected,
                  ),
                ),
                Container(
                  width: 39,
                  height: 39,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(-0.35, -0.45),
                      radius: 0.95,
                      colors: selected
                          ? const [
                              Color(0xFFFFF8D2),
                              Color(0xFFFFC857),
                              Color(0xFF8A3B00),
                            ]
                          : [
                              style.light,
                              style.main,
                              style.dark,
                            ],
                    ),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFFFFFFF)
                          : Colors.white.withValues(alpha: 0.45),
                      width: selected ? 2.2 : 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.24),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    _compact(amount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                      shadows: [
                        Shadow(color: Colors.black, blurRadius: 5),
                        Shadow(color: Colors.black, offset: Offset(0, 1)),
                      ],
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

class _CasinoChipPainter extends CustomPainter {
  const _CasinoChipPainter({
    required this.style,
    required this.selected,
  });

  final _CasinoChipStyle style;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.34)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(center + const Offset(0, 4), radius - 2, shadowPaint);

    final outerPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.45),
        radius: 0.95,
        colors: [
          style.light,
          style.main,
          style.dark,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawCircle(center, radius - 2, outerPaint);

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 4.2 : 3.2
      ..color = selected ? const Color(0xFFFFF4B8) : Colors.white.withValues(alpha: 0.34);
    canvas.drawCircle(center, radius - 5, rimPaint);

    final innerRimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = Colors.black.withValues(alpha: 0.24);
    canvas.drawCircle(center, radius - 13, innerRimPaint);

    final markPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.4
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: selected ? 0.82 : 0.58);

    final markRadius = radius - 8;
    final rect = Rect.fromCircle(center: center, radius: markRadius);
    for (var i = 0; i < 8; i++) {
      final start = (math.pi * 2 * i / 8) - 0.10;
      canvas.drawArc(rect, start, 0.20, false, markPaint);
    }

    final glossPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0x66FFFFFF),
          Color(0x18FFFFFF),
          Color(0x00FFFFFF),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height / 2.2));
    canvas.drawArc(
      Rect.fromCircle(center: center - const Offset(4, 6), radius: radius - 10),
      math.pi,
      math.pi,
      false,
      glossPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CasinoChipPainter oldDelegate) {
    return oldDelegate.style != style || oldDelegate.selected != selected;
  }
}

class _CasinoChipStyle {
  const _CasinoChipStyle({
    required this.light,
    required this.main,
    required this.dark,
  });

  final Color light;
  final Color main;
  final Color dark;
}

const List<_CasinoChipStyle> _casinoChipStyles = <_CasinoChipStyle>[
  _CasinoChipStyle(light: Color(0xFFFFF0A8), main: Color(0xFFFF9B22), dark: Color(0xFF7A3100)),
  _CasinoChipStyle(light: Color(0xFFBAE7FF), main: Color(0xFF2563EB), dark: Color(0xFF071D66)),
  _CasinoChipStyle(light: Color(0xFFB8FFDF), main: Color(0xFF0FA66A), dark: Color(0xFF063C2A)),
  _CasinoChipStyle(light: Color(0xFFFFB3CA), main: Color(0xFFE11D48), dark: Color(0xFF5A0922)),
  _CasinoChipStyle(light: Color(0xFFE5C5FF), main: Color(0xFF7C3AED), dark: Color(0xFF2A085C)),
];

class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay({required this.result, required this.didBet, required this.topWinners});

  final GameRoundResult result;
  final bool didBet;
  final List<_RoundWinner> topWinners;

  @override
  Widget build(BuildContext context) {
    final won = result.totalUserWinnings > 0;
    final title = !didBet ? 'Join now to be one of the top winner' : won ? 'You won ${_money(result.totalUserWinnings)} coins in this round' : "Bad Luck! you haven't won";
    return Container(
      color: Colors.black.withValues(alpha: 0.42),
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 18),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(colors: [Color(0xFF4A210A), Color(0xFF120804)]),
          border: Border.all(color: Color(0xFFFFD36A), width: 1.3),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 28)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, height: 1.15)),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: topWinners.take(3).map((winner) => _WinnerPodium(winner: winner)).toList()),
          ],
        ),
      ),
    );
  }
}

class _WinnerPodium extends StatelessWidget {
  const _WinnerPodium({required this.winner});

  final _RoundWinner winner;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 86,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 24, backgroundColor: const Color(0xFFFFD36A), child: Text(winner.avatar, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
          const SizedBox(height: 6),
          Text(winner.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text('${_compact(winner.coins)} 🪙', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFFFD36A), fontSize: 11, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _ErrorStrip extends StatelessWidget {
  const _ErrorStrip({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFF411524), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(child: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _JungleTarget {
  const _JungleTarget({required this.id, required this.label, required this.emoji, required this.asset, required this.multiplier, this.isBasket = false});

  final int id;
  final String label;
  final String emoji;
  final String asset;
  final int multiplier;
  final bool isBasket;
}

class _HistoryItem {
  const _HistoryItem({required this.target, required this.roundId});
  final _JungleTarget target;
  final int roundId;
}

class _RoundWinner {
  const _RoundWinner({required this.name, required this.avatar, required this.coins});
  final String name;
  final String avatar;
  final int coins;
}

const List<_JungleTarget> _targets = <_JungleTarget>[
  _JungleTarget(id: 0, label: 'Rabbit', emoji: '🐰', asset: 'assets/games/jungle_hunt/animals/animal_rabbit.png', multiplier: 5),
  _JungleTarget(id: 1, label: 'Monkey', emoji: '🐵', asset: 'assets/games/jungle_hunt/animals/animal_monkey.png', multiplier: 5),
  _JungleTarget(id: 2, label: 'Wolf', emoji: '🐺', asset: 'assets/games/jungle_hunt/animals/animal_wolf.png', multiplier: 5),
  _JungleTarget(id: 3, label: 'Deer', emoji: '🦌', asset: 'assets/games/jungle_hunt/animals/animal_deer.png', multiplier: 5),
  _JungleTarget(id: 4, label: 'Dragon', emoji: '🐉', asset: 'assets/games/jungle_hunt/animals/animal_dragon.png', multiplier: 10),
  _JungleTarget(id: 5, label: 'Panda', emoji: '🐼', asset: 'assets/games/jungle_hunt/animals/animal_panda.png', multiplier: 15),
  _JungleTarget(id: 6, label: 'Eagle', emoji: '🦅', asset: 'assets/games/jungle_hunt/animals/animal_eagle.png', multiplier: 25),
  _JungleTarget(id: 7, label: 'Lion', emoji: '🦁', asset: 'assets/games/jungle_hunt/animals/animal_lion.png', multiplier: 45),
];

const List<int> _amounts = <int>[10000, 50000, 100000, 500000, 1000000];



_JungleTarget _targetForHistoryId(int id) {
  if (id == 100) {
    return const _JungleTarget(
      id: 100,
      label: 'Basket',
      emoji: '??',
      asset: '',
      multiplier: 0,
      isBasket: true,
    );
  }

  if (id == 101) {
    return const _JungleTarget(
      id: 101,
      label: 'Basket',
      emoji: '??',
      asset: '',
      multiplier: 0,
      isBasket: true,
    );
  }

  return _targets.firstWhere((target) => target.id == id, orElse: () => _targets.first);
}
String _phaseLabel(_JunglePhase phase) {
  switch (phase) {
    case _JunglePhase.loading:
      return 'Loading';
    case _JunglePhase.betting:
      return 'Select';
    case _JunglePhase.locked:
      return 'Locked';
    case _JunglePhase.revealing:
      return 'Reveal';
    case _JunglePhase.result:
      return 'Result';
  }
}

String _compact(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
  if (value >= 10000) return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
  return '$value';
}

String _money(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final reverseIndex = raw.length - i;
    buffer.write(raw[i]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}















