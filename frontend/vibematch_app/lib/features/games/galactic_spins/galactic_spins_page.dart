import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class GalacticSpinsPage extends StatefulWidget {
  const GalacticSpinsPage({super.key});

  @override
  State<GalacticSpinsPage> createState() => _GalacticSpinsPageState();
}

class _GalacticSpinsPageState extends State<GalacticSpinsPage>
    with SingleTickerProviderStateMixin {
  final math.Random _rng = math.Random();
  late final AnimationController _spinController;
  late List<List<_SlotSymbol>> _reels;
  Timer? _autoTimer;
  int _balance = 25000;
  int _bet = 100;
  int _lines = 25;
  int _lastWin = 0;
  bool _spinning = false;
  bool _autoPlay = false;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _reels = _newReels();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _spinController.dispose();
    super.dispose();
  }

  List<List<_SlotSymbol>> _newReels() => List.generate(
        5,
        (_) => List.generate(
          3,
          (_) => _weighted[_rng.nextInt(_weighted.length)],
        ),
      );

  Future<void> _spin() async {
    if (_spinning) return;
    if (_balance < _bet) return _toast('Insufficient test coins');
    setState(() {
      _spinning = true;
      _lastWin = 0;
      _balance -= _bet;
    });
    await _spinController.forward(from: 0);
    final reels = _newReels();
    final rawWin = _score(reels);
    final win = math.min(rawWin, _bet * 50);
    setState(() {
      _reels = reels;
      _lastWin = win;
      _balance += win;
      _spinning = false;
    });
    if (win > 0) _toast('You won $win test coins');
  }

  int _score(List<List<_SlotSymbol>> reels) {
    final stake = math.max(1, _bet ~/ math.max(_lines, 1));
    int total = 0;
    for (final line in _payLines.take(_lines)) {
      var first = reels.first[line.first];
      int count = 1;
      for (int reel = 1; reel < reels.length; reel++) {
        final next = reels[reel][line[reel]];
        final matched = next == first || next == _SlotSymbol.wild || first == _SlotSymbol.wild;
        if (!matched) break;
        if (first == _SlotSymbol.wild && next != _SlotSymbol.wild) first = next;
        count++;
      }
      total += stake * (_paytable[first]?[count] ?? 0);
    }
    return total;
  }

  void _toggleAutoPlay() {
    setState(() => _autoPlay = !_autoPlay);
    _autoTimer?.cancel();
    if (_autoPlay) {
      _autoTimer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
        if (mounted && !_spinning && _balance >= _bet) _spin();
      });
      _toast('Auto play started');
    } else {
      _toast('Auto play stopped');
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF121832),
        content: Text(message),
      ),
    );
  }

  void _openInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(14),
        padding: EdgeInsets.fromLTRB(16, 16, 16, 18 + MediaQuery.paddingOf(context).bottom),
        decoration: BoxDecoration(
          color: const Color(0xFF10162F),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF38E8FF).withValues(alpha: 0.35)),
        ),
        child: const Text(
          'Galactic Spins now uses the packaged SVG assets from assets/images/games/galactic_spins. Production mode should call /games/galactic-spins/spin so backend owns RNG, wallet movement, payout caps, risk controls, and audit logs.',
          style: TextStyle(color: Color(0xFFD7E5FF), fontSize: 13, height: 1.35, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF070A18),
        body: SafeArea(
          child: Stack(
            children: [
              const _SpaceBackground(),
              Column(
                children: [
                  _Header(
                    muted: _muted,
                    onBack: () => Navigator.pop(context),
                    onSoundTap: () {
                      setState(() => _muted = !_muted);
                      _toast(_muted ? 'Sound muted' : 'Sound enabled');
                    },
                  ),
                  Expanded(child: _body()),
                  _controls(),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _body() => SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(children: [
              Expanded(child: _InfoPanel(label: 'Balance', value: '$_balance', color: const Color(0xFF38E8FF))),
              const SizedBox(width: 10),
              Expanded(child: _InfoPanel(label: 'Last win', value: '$_lastWin', color: const Color(0xFFFFD76A))),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(colors: [Color(0xFF101A3A), Color(0xFF251052), Color(0xFF101A3A)]),
                border: Border.all(color: const Color(0xFFB54DFF), width: 1.4),
                boxShadow: [BoxShadow(color: const Color(0xFFB54DFF).withValues(alpha: 0.22), blurRadius: 26)],
              ),
              child: AnimatedBuilder(
                animation: _spinController,
                builder: (_, __) => Row(
                  children: List.generate(_reels.length, (reelIndex) {
                    final shift = _spinning ? math.sin((_spinController.value * math.pi * 8) + reelIndex) * 8 : 0.0;
                    return Expanded(
                      child: Transform.translate(
                        offset: Offset(0, shift),
                        child: _ReelColumn(symbols: _reels[reelIndex]),
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _InfoPanel(label: 'Lines', value: '$_lines', color: const Color(0xFF38E8FF), onTap: _changeLines)),
              const SizedBox(width: 10),
              Expanded(child: _InfoPanel(label: 'Bet', value: '$_bet', color: const Color(0xFFFFD76A))),
            ]),
          ],
        ),
      );

  void _changeLines() {
    const values = [1, 5, 10, 15, 20, 25];
    final index = values.indexOf(_lines);
    setState(() => _lines = values[(index + 1) % values.length]);
  }

  Widget _controls() => Container(
        padding: EdgeInsets.fromLTRB(12, 10, 12, 12 + MediaQuery.paddingOf(context).bottom),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1229).withValues(alpha: 0.96),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: const Color(0xFF273D80)),
        ),
        child: Row(children: [
          _SmallButton(icon: Icons.remove_rounded, onTap: () => setState(() => _bet = (_bet - 10).clamp(10, 100000))),
          const SizedBox(width: 8),
          Expanded(child: _DeckButton(label: _autoPlay ? 'STOP' : 'AUTO', icon: Icons.repeat_rounded, onTap: _toggleAutoPlay)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _spinning ? null : _spin,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 160),
              scale: _spinning ? 0.94 : 1,
              child: SizedBox(
                width: 94,
                height: 74,
                child: SvgPicture.asset('assets/images/games/galactic_spins/ui/button_spin.svg', fit: BoxFit.contain),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: _DeckButton(label: 'INFO', icon: Icons.info_rounded, onTap: _openInfo)),
          const SizedBox(width: 8),
          _SmallButton(icon: Icons.add_rounded, onTap: () => setState(() => _bet = (_bet + 10).clamp(10, 100000))),
        ]),
      );
}

enum _SlotSymbol { wild, diamond, seven, bar, grapes, cherries, orange }

const List<_SlotSymbol> _weighted = [
  _SlotSymbol.orange, _SlotSymbol.orange, _SlotSymbol.orange, _SlotSymbol.orange,
  _SlotSymbol.cherries, _SlotSymbol.cherries, _SlotSymbol.cherries,
  _SlotSymbol.grapes, _SlotSymbol.grapes, _SlotSymbol.bar, _SlotSymbol.bar,
  _SlotSymbol.seven, _SlotSymbol.diamond, _SlotSymbol.wild,
];

const Map<_SlotSymbol, Map<int, int>> _paytable = {
  _SlotSymbol.orange: {3: 2, 4: 5, 5: 12},
  _SlotSymbol.cherries: {3: 3, 4: 8, 5: 18},
  _SlotSymbol.grapes: {3: 4, 4: 10, 5: 25},
  _SlotSymbol.bar: {3: 6, 4: 18, 5: 45},
  _SlotSymbol.seven: {3: 10, 4: 35, 5: 90},
  _SlotSymbol.diamond: {3: 18, 4: 65, 5: 180},
  _SlotSymbol.wild: {3: 25, 4: 100, 5: 300},
};

const List<List<int>> _payLines = [
  [1, 1, 1, 1, 1], [0, 0, 0, 0, 0], [2, 2, 2, 2, 2], [0, 1, 2, 1, 0], [2, 1, 0, 1, 2],
  [0, 0, 1, 2, 2], [2, 2, 1, 0, 0], [1, 0, 0, 0, 1], [1, 2, 2, 2, 1], [0, 1, 1, 1, 0],
  [2, 1, 1, 1, 2], [1, 0, 1, 2, 1], [1, 2, 1, 0, 1], [0, 1, 0, 1, 0], [2, 1, 2, 1, 2],
  [1, 1, 0, 1, 1], [1, 1, 2, 1, 1], [0, 2, 0, 2, 0], [2, 0, 2, 0, 2], [0, 2, 2, 2, 0],
  [2, 0, 0, 0, 2], [0, 0, 2, 0, 0], [2, 2, 0, 2, 2], [1, 0, 2, 0, 1], [1, 2, 0, 2, 1],
];

extension _SlotSymbolX on _SlotSymbol {
  String get assetPath => switch (this) {
        _SlotSymbol.wild => 'assets/images/games/galactic_spins/symbols/symbol_wild_star.svg',
        _SlotSymbol.diamond => 'assets/images/games/galactic_spins/symbols/symbol_diamond.svg',
        _SlotSymbol.seven => 'assets/images/games/galactic_spins/symbols/symbol_seven.svg',
        _SlotSymbol.bar => 'assets/images/games/galactic_spins/symbols/symbol_bar.svg',
        _SlotSymbol.grapes => 'assets/images/games/galactic_spins/symbols/symbol_grapes.svg',
        _SlotSymbol.cherries => 'assets/images/games/galactic_spins/symbols/symbol_cherries.svg',
        _SlotSymbol.orange => 'assets/images/games/galactic_spins/symbols/symbol_orange.svg',
      };
  Color get color => switch (this) {
        _SlotSymbol.wild => const Color(0xFFFFD76A), _SlotSymbol.diamond => const Color(0xFF38E8FF),
        _SlotSymbol.seven => const Color(0xFFFF345F), _SlotSymbol.bar => const Color(0xFFFF5DFF),
        _SlotSymbol.grapes => const Color(0xFF9B61FF), _SlotSymbol.cherries => const Color(0xFFFF345F),
        _SlotSymbol.orange => const Color(0xFFFF9F38),
      };
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack, required this.onSoundTap, required this.muted});
  final VoidCallback onBack;
  final VoidCallback onSoundTap;
  final bool muted;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        child: Row(children: [
          _SmallButton(icon: Icons.arrow_back_rounded, onTap: onBack),
          const SizedBox(width: 10),
          Expanded(child: SizedBox(height: 72, child: SvgPicture.asset('assets/images/games/galactic_spins/ui/logo_galactic_spins.svg', fit: BoxFit.contain))),
          const SizedBox(width: 10),
          _SmallButton(icon: muted ? Icons.volume_off_rounded : Icons.volume_up_rounded, onTap: onSoundTap),
        ]),
      );
}

class _ReelColumn extends StatelessWidget {
  const _ReelColumn({required this.symbols});
  final List<_SlotSymbol> symbols;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFF070B1B), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF273D80))),
        child: Column(children: symbols.map((s) => Expanded(child: _SymbolTile(symbol: s))).toList()),
      );
}

class _SymbolTile extends StatelessWidget {
  const _SymbolTile({required this.symbol});
  final _SlotSymbol symbol;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(colors: [symbol.color.withValues(alpha: 0.30), const Color(0xFF111B3A)]),
          border: Border.all(color: symbol.color.withValues(alpha: 0.6)),
        ),
        child: Center(child: SvgPicture.asset(symbol.assetPath, fit: BoxFit.contain)),
      );
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.label, required this.value, required this.color, this.onTap});
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFF0D1430), borderRadius: BorderRadius.circular(18), border: Border.all(color: color.withValues(alpha: 0.55))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(), style: const TextStyle(color: Color(0xFF9CB9FF), fontSize: 11, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w900)),
          ]),
        ),
      );
}

class _DeckButton extends StatelessWidget {
  const _DeckButton({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: const LinearGradient(colors: [Color(0xFF12387E), Color(0xFF101A3A)]), border: Border.all(color: const Color(0xFF38E8FF))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.white, size: 18), const SizedBox(width: 5), Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)))]),
        ),
      );
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFF101A3A), borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFF38E8FF).withValues(alpha: 0.5))), child: Icon(icon, color: const Color(0xFFBDEEFF), size: 21)),
      );
}

class _SpaceBackground extends StatelessWidget {
  const _SpaceBackground();
  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: RadialGradient(center: Alignment.topCenter, radius: 1.2, colors: [const Color(0xFF263C8B).withValues(alpha: 0.7), const Color(0xFF140929), const Color(0xFF070B1B)])),
          child: const SizedBox.expand(),
        ),
      );
}
