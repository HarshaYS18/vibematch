import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/game_api_service.dart';

class JungleHuntGamePage extends StatefulWidget {
  const JungleHuntGamePage({super.key});

  @override
  State<JungleHuntGamePage> createState() => _JungleHuntGamePageState();
}

class _JungleHuntGamePageState extends State<JungleHuntGamePage> {
  final GameApiService _api = const GameApiService();
  final Map<int, int> _placedByTarget = <int, int>{};
  Timer? _timer;
  GameDefinition? _game;
  GameRound? _round;
  GameRoundResult? _result;
  int? _selectedTargetId;
  int _selectedAmount = 400;
  int _secondsLeft = 0;
  bool _loading = false;
  String? _error;

  bool get _isOpen => _round != null && _secondsLeft > 0 && !_loading;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _timer?.cancel();
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
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
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
        _selectedTargetId = _targets(game).first.id;
        _selectedAmount = _amounts(game).first;
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
        _placedByTarget.clear();
        _secondsLeft = _roundSeconds(game);
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (_secondsLeft <= 1) {
          setState(() => _secondsLeft = 0);
          _timer?.cancel();
          unawaited(_finishRound());
        } else {
          setState(() => _secondsLeft -= 1);
        }
      });
    });
  }

  Future<void> _placeOn(GameTarget target) async {
    final round = _round;
    if (round == null || !_isOpen) return;
    setState(() => _selectedTargetId = target.id);
    await _busy(() async {
      final result = await _api.placeBet(roundId: round.id, targetId: target.id, amount: _selectedAmount);
      if (!mounted) return;
      if (result.acceptedAmount > 0) {
        setState(() {
          _placedByTarget[target.id] = (_placedByTarget[target.id] ?? 0) + result.acceptedAmount;
        });
      }
    });
  }

  Future<void> _finishRound() async {
    final round = _round;
    if (round == null || _result != null) return;
    await _busy(() async {
      final result = await _api.settleTestRound(round.id);
      if (mounted) setState(() => _result = result);
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    final targets = _targets(game);
    final amounts = _amounts(game);

    return Scaffold(
      backgroundColor: const Color(0xFF06140B),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/games/jungle_hunt/backgrounds/bg_jungle_hunt.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const DecoratedBox(
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
          Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.20))),
          SafeArea(
            child: Column(
              children: [
                _Header(roundId: _round?.id, onClose: () => Navigator.pop(context)),
                if (_error != null) _ErrorStrip(message: _error!, onRetry: _load),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _TargetWheel(
                        targets: targets,
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
                      if (_result != null) Positioned(top: 18, left: 14, right: 14, child: _ResultBanner(result: _result!)),
                    ],
                  ),
                ),
                _BottomPanel(
                  amounts: amounts,
                  selectedAmount: _selectedAmount,
                  totalPlaced: _placedByTarget.values.fold<int>(0, (sum, item) => sum + item),
                  onAmount: (amount) => setState(() => _selectedAmount = amount),
                ),
              ],
            ),
          ),
          if (_loading)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.10),
                  alignment: Alignment.center,
                  child: const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(color: Color(0xFFFFD36A), strokeWidth: 2.4)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.roundId, required this.onClose});
  final int? roundId;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 6),
      child: Row(
        children: [
          const Text('🦁', style: TextStyle(fontSize: 34)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Jungle Hunt', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                Text(roundId == null ? 'Room coin game' : 'Round #$roundId', style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 12, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30)),
        ],
      ),
    );
  }
}

class _TargetWheel extends StatelessWidget {
  const _TargetWheel({required this.targets, required this.selectedId, required this.winnerId, required this.placedByTarget, required this.isOpen, required this.onTap});
  final List<GameTarget> targets;
  final int? selectedId;
  final int? winnerId;
  final Map<int, int> placedByTarget;
  final bool isOpen;
  final ValueChanged<GameTarget> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final shortest = math.min(constraints.maxWidth, constraints.maxHeight);
        final radius = (shortest * 0.34).clamp(112.0, 182.0);
        final item = (shortest * 0.23).clamp(78.0, 112.0);
        final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
        return Stack(
          children: [
            Center(
              child: Container(
                width: radius * 2.18,
                height: radius * 2.18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF58310F).withValues(alpha: 0.72),
                  border: Border.all(color: const Color(0xFFFFC557), width: 8),
                ),
              ),
            ),
            for (var i = 0; i < targets.length; i++)
              Positioned(
                left: center.dx + math.cos(-math.pi / 2 + math.pi * 2 * i / targets.length) * radius - item / 2,
                top: center.dy + math.sin(-math.pi / 2 + math.pi * 2 * i / targets.length) * radius - item / 2,
                width: item,
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
  final GameTarget target;
  final bool selected;
  final bool winner;
  final int placed;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final display = _display(target);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedScale(
        scale: winner ? 1.14 : selected ? 1.06 : 1.0,
        duration: const Duration(milliseconds: 160),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: winner ? const [Color(0xFFFFF176), Color(0xFFFF8F00)] : selected ? const [Color(0xFF41F7A9), Color(0xFF087D54)] : const [Color(0xFFFFD36A), Color(0xFF7B3E11)]),
                boxShadow: selected || winner ? [BoxShadow(color: const Color(0xFFFFD36A).withValues(alpha: 0.45), blurRadius: 18)] : null,
              ),
              child: ClipOval(
                child: Container(
                  width: 64,
                  height: 64,
                  color: const Color(0xFF251207),
                  child: Image.asset(display.asset, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Text(display.emoji, style: const TextStyle(fontSize: 34)))),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFF4D2410), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFFD36A))),
              child: Text('${target.multiplier}x', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
            ),
            if (placed > 0) Text(_compact(placed), style: const TextStyle(color: Color(0xFFFFD36A), fontSize: 10, fontWeight: FontWeight.w900)),
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
        width: 132,
        height: 132,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [Color(0xFFFFE8A8), Color(0xFFFF9E2D)]), border: Border.all(color: const Color(0xFF71370E), width: 8)),
        alignment: Alignment.center,
        child: Text(active ? '${secondsLeft}s' : result == null ? 'START' : 'NEXT', style: const TextStyle(color: Color(0xFF4A210A), fontSize: 28, fontWeight: FontWeight.w900)),
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
      padding: EdgeInsets.fromLTRB(10, 10, 10, MediaQuery.paddingOf(context).bottom + 10),
      decoration: const BoxDecoration(color: Color(0xFF5A3212), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            const Text('🪙', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 6),
            Expanded(child: Text('This round: ${_money(totalPlaced)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 9),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: amounts.map((amount) => Padding(padding: const EdgeInsets.only(right: 8), child: _AmountChip(amount: amount, selected: amount == selectedAmount, onTap: () => onAmount(amount)))).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountChip extends StatelessWidget {
  const _AmountChip({required this.amount, required this.selected, required this.onTap});
  final int amount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 62,
        height: 62,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: selected ? const [Color(0xFFFFF176), Color(0xFFFF8F00)] : const [Color(0xFF2D8CFF), Color(0xFF053D90)]), border: Border.all(color: Colors.white.withValues(alpha: selected ? 0.72 : 0.25), width: selected ? 3 : 1.2)),
        child: Text(_compact(amount), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black, blurRadius: 2)])),
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.result});
  final GameRoundResult result;

  @override
  Widget build(BuildContext context) {
    final won = result.totalUserWinnings > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: won ? const Color(0xFF0B7D3B) : const Color(0xFF5A3212), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFFD36A))),
      child: Text(won ? 'You won ${_money(result.totalUserWinnings)} coins' : 'Winning target: ${result.winningTargetId}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
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
      child: Row(children: [Expanded(child: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))), TextButton(onPressed: onRetry, child: const Text('Retry'))]),
    );
  }
}

class _AnimalDisplay {
  const _AnimalDisplay(this.asset, this.emoji);
  final String asset;
  final String emoji;
}

_AnimalDisplay _display(GameTarget target) {
  final label = target.label.toLowerCase();
  final map = <String, _AnimalDisplay>{
    'lion': const _AnimalDisplay('assets/games/jungle_hunt/animals/animal_lion.png', '🦁'),
    'tiger': const _AnimalDisplay('assets/games/jungle_hunt/animals/animal_tiger.png', '🐯'),
    'elephant': const _AnimalDisplay('assets/games/jungle_hunt/animals/animal_elephant.png', '🐘'),
    'panda': const _AnimalDisplay('assets/games/jungle_hunt/animals/animal_panda.png', '🐼'),
    'monkey': const _AnimalDisplay('assets/games/jungle_hunt/animals/animal_monkey.png', '🐵'),
    'fox': const _AnimalDisplay('assets/games/jungle_hunt/animals/animal_fox.png', '🦊'),
    'rabbit': const _AnimalDisplay('assets/games/jungle_hunt/animals/animal_rabbit.png', '🐰'),
    'deer': const _AnimalDisplay('assets/games/jungle_hunt/animals/animal_deer.png', '🦌'),
    'shark': const _AnimalDisplay('assets/games/jungle_hunt/animals/animal_shark.png', '🦈'),
    'dolphin': const _AnimalDisplay('assets/games/jungle_hunt/animals/animal_shark.png', '🐬'),
    'croc': const _AnimalDisplay('assets/games/jungle_hunt/animals/animal_crocodile.png', '🐊'),
    'eagle': const _AnimalDisplay('assets/games/jungle_hunt/animals/animal_eagle.png', '🦅'),
    'dragon': const _AnimalDisplay('assets/games/jungle_hunt/animals/animal_dragon.png', '🐉'),
  };
  for (final entry in map.entries) {
    if (label.contains(entry.key)) return entry.value;
  }
  return _AnimalDisplay('assets/games/jungle_hunt/animals/animal_lion.png', target.emoji ?? '🎯');
}

List<GameTarget> _targets(GameDefinition? game) {
  final targets = game?.targets ?? const <GameTarget>[];
  if (targets.isNotEmpty) return targets;
  return const <GameTarget>[
    GameTarget(id: 0, label: 'Rabbit', emoji: '🐰', multiplier: 5, themeColor: null),
    GameTarget(id: 1, label: 'Panda', emoji: '🐼', multiplier: 8, themeColor: null),
    GameTarget(id: 2, label: 'Shark', emoji: '🦈', multiplier: 10, themeColor: null),
    GameTarget(id: 3, label: 'Monkey', emoji: '🐵', multiplier: 12, themeColor: null),
    GameTarget(id: 4, label: 'Fox', emoji: '🦊', multiplier: 15, themeColor: null),
    GameTarget(id: 5, label: 'Tiger', emoji: '🐯', multiplier: 25, themeColor: null),
    GameTarget(id: 6, label: 'Eagle', emoji: '🦅', multiplier: 30, themeColor: null),
    GameTarget(id: 7, label: 'Lion', emoji: '🦁', multiplier: 45, themeColor: null),
  ];
}

List<int> _amounts(GameDefinition? game) {
  final values = game?.allowedBets ?? const <int>[];
  if (values.isEmpty) return const <int>[10, 100, 500, 1000, 10000];
  return values.take(6).toList(growable: false);
}

int _roundSeconds(GameDefinition game) {
  final value = game.rules['round_seconds'];
  if (value is num && value > 0) return value.toInt().clamp(8, 60);
  return 24;
}

String _compact(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
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
