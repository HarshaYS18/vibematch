import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/game_api_service.dart';

class JungleHuntGamePage extends StatefulWidget {
  const JungleHuntGamePage({super.key, this.embeddedInRoom = false});

  final bool embeddedInRoom;

  @override
  State<JungleHuntGamePage> createState() => _JungleHuntGamePageState();
}

class _JungleHuntGamePageState extends State<JungleHuntGamePage> {
  final GameApiService _api = const GameApiService();
  final Map<int, int> _placedByTarget = <int, int>{};
  final List<_HistoryItem> _history = <_HistoryItem>[];

  Timer? _timer;
  Timer? _overlayTimer;
  GameDefinition? _game;
  GameRound? _round;
  GameRoundResult? _result;
  int? _selectedTargetId;
  int _selectedAmount = 10000;
  int _secondsLeft = 0;
  bool _loading = false;
  bool _showResultOverlay = false;
  String? _error;

  bool get _isOpen => _round != null && _secondsLeft > 0 && !_loading;
  bool get _didBet => _placedByTarget.values.fold<int>(0, (sum, item) => sum + item) > 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _overlayTimer?.cancel();
    super.dispose();
  }

  Future<void> _busy(Future<void> Function() task) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await task();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _load() async {
    await _busy(() async {
      var games = await _api.loadCatalog();
      if (games.isEmpty) games = <GameDefinition>[await _api.seedDefaultGames()];
      final enabled = games.where((game) => game.isEnabled).toList();
      final list = enabled.isEmpty ? games : enabled;
      final game = list.firstWhere(
        (item) => item.gameKey == 'jungle_hunt' || item.gameKey == 'jackpot_king',
        orElse: () => list.first,
      );
      if (!mounted) return;
      setState(() {
        _game = game;
        _selectedTargetId = _targets.first.id;
        _selectedAmount = _amounts.first;
      });
    });
  }

  Future<void> _startRound() async {
    final game = _game;
    if (game == null) return;
    await _busy(() async {
      final round = await _api.createRound(gameKey: game.gameKey);
      if (!mounted) return;
      setState(() {
        _round = round;
        _result = null;
        _showResultOverlay = false;
        _placedByTarget.clear();
        _secondsLeft = _roundSeconds(game);
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        if (_secondsLeft <= 1) {
          setState(() => _secondsLeft = 0);
          timer.cancel();
          unawaited(_finishRound());
          return;
        }
        setState(() => _secondsLeft -= 1);
      });
    });
  }

  Future<void> _placeOn(_JungleTarget target) async {
    final round = _round;
    if (round == null || !_isOpen) return;
    setState(() => _selectedTargetId = target.id);
    await _busy(() async {
      final result = await _api.placeBet(
        roundId: round.id,
        targetId: target.id,
        amount: _selectedAmount,
      );
      if (!mounted || result.acceptedAmount <= 0) return;
      setState(() {
        _placedByTarget[target.id] =
            (_placedByTarget[target.id] ?? 0) + result.acceptedAmount;
      });
    });
  }

  Future<void> _finishRound() async {
    final round = _round;
    if (round == null || _result != null) return;
    await _busy(() async {
      final result = await _api.settleTestRound(round.id);
      if (!mounted) return;
      final winner = _targetForId(result.winningTargetId);
      setState(() {
        _result = result;
        _history.insert(0, _HistoryItem(target: winner, roundId: result.roundId));
        if (_history.length > 8) _history.removeLast();
        _showResultOverlay = true;
      });
      _overlayTimer?.cancel();
      _overlayTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() => _showResultOverlay = false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final shell = ClipRRect(
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
                    history: _history,
                    onClose: () => Navigator.pop(context),
                  ),
                  if (_error != null) _ErrorStrip(message: _error!, onRetry: _load),
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _TargetWheel(
                          targets: _targets,
                          selectedId: _selectedTargetId,
                          winnerId: _result?.winningTargetId,
                          placedByTarget: _placedByTarget,
                          isOpen: _isOpen,
                          onTap: _placeOn,
                        ),
                        _TimerButton(
                          secondsLeft: _secondsLeft,
                          loading: _loading,
                          result: _result,
                          onStart: _startRound,
                        ),
                      ],
                    ),
                  ),
                  _BottomPanel(
                    amounts: _amounts,
                    selectedAmount: _selectedAmount,
                    totalPlaced: _placedByTarget.values.fold<int>(0, (sum, item) => sum + item),
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
            if (_loading)
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

    return widget.embeddedInRoom ? shell : shell;
  }

  List<_RoundWinner> _topWinners(GameRoundResult result) {
    final base = math.max(result.totalUserWinnings, result.multiplier * 10000);
    return <_RoundWinner>[
      _RoundWinner(name: 'Aarav', avatar: '🧑', coins: base + 120000),
      _RoundWinner(name: 'Meera', avatar: '👩', coins: (base * 0.72).round()),
      _RoundWinner(name: 'Vikram', avatar: '🧔', coins: (base * 0.46).round()),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.roundId, required this.history, required this.onClose});

  final int? roundId;
  final List<_HistoryItem> history;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 5),
      child: Row(
        children: [
          const Text('🦁', style: TextStyle(fontSize: 30)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Jungle Hunt', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      roundId == null ? 'Ready' : 'Round #$roundId',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: _HistoryStrip(history: history)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28)),
        ],
      ),
    );
  }
}

class _HistoryStrip extends StatelessWidget {
  const _HistoryStrip({required this.history});

  final List<_HistoryItem> history;

  @override
  Widget build(BuildContext context) {
    final items = history.isEmpty ? _targets.take(5).map((target) => _HistoryItem(target: target, roundId: 0)).toList() : history;
    return SizedBox(
      height: 24,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length.clamp(0, 8),
        separatorBuilder: (context, index) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final item = items[index];
          return Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFD36A).withValues(alpha: 0.70)),
              color: const Color(0xFF2A1306),
            ),
            child: ClipOval(
              child: Image.asset(
                item.target.asset,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(child: Text(item.target.emoji, style: const TextStyle(fontSize: 13))),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TargetWheel extends StatelessWidget {
  const _TargetWheel({required this.targets, required this.selectedId, required this.winnerId, required this.placedByTarget, required this.isOpen, required this.onTap});

  final List<_JungleTarget> targets;
  final int? selectedId;
  final int? winnerId;
  final Map<int, int> placedByTarget;
  final bool isOpen;
  final ValueChanged<_JungleTarget> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final shortest = math.min(constraints.maxWidth, constraints.maxHeight);
        final radius = (shortest * 0.33).clamp(102.0, 154.0);
        final item = (shortest * 0.23).clamp(76.0, 100.0);
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
  const _TargetTile({required this.target, required this.selected, required this.winner, required this.placed, required this.enabled, required this.onTap});

  final _JungleTarget target;
  final bool selected;
  final bool winner;
  final int placed;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedScale(
        scale: winner ? 1.14 : selected ? 1.06 : 1.0,
        duration: const Duration(milliseconds: 160),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: winner
                      ? const [Color(0xFFFFF6A5), Color(0xFFFF8F00)]
                      : selected
                          ? const [Color(0xFF66FFD0), Color(0xFF087D54)]
                          : const [Color(0xFFFFD36A), Color(0xFF7B3E11)],
                ),
                boxShadow: selected || winner ? [BoxShadow(color: const Color(0xFFFFD36A).withValues(alpha: 0.45), blurRadius: 18)] : null,
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

class _TimerButton extends StatelessWidget {
  const _TimerButton({required this.secondsLeft, required this.loading, required this.result, required this.onStart});

  final int secondsLeft;
  final bool loading;
  final GameRoundResult? result;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final active = secondsLeft > 0;
    return GestureDetector(
      onTap: active || loading ? null : onStart,
      child: Container(
        width: 122,
        height: 122,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: [Color(0xFFFFE8A8), Color(0xFFFF9E2D)]),
          border: Border.all(color: const Color(0xFF71370E), width: 8),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: Text(active ? '${secondsLeft}s' : result == null ? 'START' : 'NEXT', style: const TextStyle(color: Color(0xFF4A210A), fontSize: 26, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({required this.amounts, required this.selectedAmount, required this.totalPlaced, required this.onAmount});

  final List<int> amounts;
  final int selectedAmount;
  final int totalPlaced;
  final ValueChanged<int> onAmount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(10, 9, 10, MediaQuery.paddingOf(context).bottom + 9),
      decoration: BoxDecoration(
        color: const Color(0xFF2D1809).withValues(alpha: 0.92),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
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
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: amounts.map((amount) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _AmountPill(amount: amount, selected: amount == selectedAmount, onTap: () => onAmount(amount)),
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
  const _AmountPill({required this.amount, required this.selected, required this.onTap});

  final int amount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selected
                ? const [Color(0xFFFFF4A5), Color(0xFFFFB23F), Color(0xFFB65B12)]
                : const [Color(0xFF84E6FF), Color(0xFF2B7DFF), Color(0xFF3124A8)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: selected ? 0.78 : 0.30), width: selected ? 2 : 1),
          boxShadow: selected ? [BoxShadow(color: const Color(0xFFFFD36A).withValues(alpha: 0.34), blurRadius: 12)] : null,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              top: 2,
              left: 5,
              right: 5,
              bottom: 24,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white.withValues(alpha: 0.28),
                ),
              ),
            ),
            Center(
              child: Text(_compact(amount), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black, blurRadius: 3)])),
            ),
          ],
        ),
      ),
    );
  }
}

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: topWinners.take(3).map((winner) => _WinnerPodium(winner: winner)).toList(),
            ),
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
          CircleAvatar(radius: 24, backgroundColor: const Color(0xFFFFD36A), child: Text(winner.avatar, style: const TextStyle(fontSize: 24))),
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
  const _JungleTarget({required this.id, required this.label, required this.emoji, required this.asset, required this.multiplier});

  final int id;
  final String label;
  final String emoji;
  final String asset;
  final int multiplier;
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
  _JungleTarget(id: 1, label: 'Panda', emoji: '🐼', asset: 'assets/games/jungle_hunt/animals/animal_panda.png', multiplier: 8),
  _JungleTarget(id: 2, label: 'Shark', emoji: '🦈', asset: 'assets/games/jungle_hunt/animals/animal_shark.png', multiplier: 10),
  _JungleTarget(id: 3, label: 'Monkey', emoji: '🐵', asset: 'assets/games/jungle_hunt/animals/animal_monkey.png', multiplier: 12),
  _JungleTarget(id: 4, label: 'Fox', emoji: '🦊', asset: 'assets/games/jungle_hunt/animals/animal_fox.png', multiplier: 15),
  _JungleTarget(id: 5, label: 'Tiger', emoji: '🐯', asset: 'assets/games/jungle_hunt/animals/animal_tiger.png', multiplier: 25),
  _JungleTarget(id: 6, label: 'Eagle', emoji: '🦅', asset: 'assets/games/jungle_hunt/animals/animal_eagle.png', multiplier: 30),
  _JungleTarget(id: 7, label: 'Lion', emoji: '🦁', asset: 'assets/games/jungle_hunt/animals/animal_lion.png', multiplier: 45),
];

const List<int> _amounts = <int>[10000, 50000, 100000, 500000, 1000000];

_JungleTarget _targetForId(int id) {
  return _targets.firstWhere((target) => target.id == id, orElse: () => _targets.first);
}

int _roundSeconds(GameDefinition game) {
  final value = game.rules['round_seconds'];
  if (value is num && value > 0) return value.toInt().clamp(8, 60);
  return 24;
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
