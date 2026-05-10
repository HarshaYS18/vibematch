import 'package:flutter/material.dart';

import '../data/game_api_service.dart';

class GameTestPage extends StatefulWidget {
  const GameTestPage({super.key});

  @override
  State<GameTestPage> createState() => _GameTestPageState();
}

class _GameTestPageState extends State<GameTestPage> {
  final GameApiService _api = const GameApiService();

  List<GameDefinition> _games = const <GameDefinition>[];
  GameDefinition? _selectedGame;
  GameRound? _round;
  GameBetResult? _lastBet;
  GameRoundResult? _lastResult;
  int? _selectedTargetId;
  int _selectedAmount = 400;
  bool _loading = false;
  bool _tapIgnoredOverlay = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)), behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF251538)));
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadCatalog() async {
    await _runBusy(() async {
      var games = await _api.loadCatalog();
      if (games.isEmpty) {
        final seeded = await _api.seedDefaultGames();
        games = [seeded];
      }
      final enabled = games.where((game) => game.isEnabled).toList(growable: false);
      final nextGames = enabled.isEmpty ? games : enabled;
      if (!mounted) return;
      setState(() {
        _games = nextGames;
        _selectedGame = nextGames.isEmpty ? null : nextGames.first;
        final targets = _selectedGame?.targets ?? const <GameTarget>[];
        _selectedTargetId = targets.isEmpty ? null : targets.first.id;
        final bets = _selectedGame?.allowedBets ?? const [400, 10000, 100000];
        _selectedAmount = bets.isEmpty ? 400 : bets.first;
      });
    });
  }

  Future<void> _createRound() async {
    final game = _selectedGame;
    if (game == null) {
      _toast('No game selected.');
      return;
    }
    await _runBusy(() async {
      final round = await _api.createRound(gameKey: game.gameKey);
      if (!mounted) return;
      setState(() {
        _round = round;
        _lastBet = null;
        _lastResult = null;
        _tapIgnoredOverlay = false;
      });
      _toast('Round #${round.id} started.');
    });
  }

  Future<void> _placeBet() async {
    final round = _round;
    final targetId = _selectedTargetId;
    if (round == null) {
      _toast('Start a round first.');
      return;
    }
    if (targetId == null) {
      _toast('Select a target first.');
      return;
    }
    await _runBusy(() async {
      final result = await _api.placeBet(roundId: round.id, targetId: targetId, amount: _selectedAmount);
      if (!mounted) return;
      setState(() {
        _lastBet = result;
        _tapIgnoredOverlay = result.shouldShowLoadingOverlay;
      });
      if (result.shouldShowLoadingOverlay) {
        Future<void>.delayed(const Duration(milliseconds: 950), () {
          if (mounted) setState(() => _tapIgnoredOverlay = false);
        });
        return;
      }
      _toast(result.wasLimited ? 'Bet accepted with safety limit: ${_format(result.acceptedAmount)}' : 'Bet accepted: ${_format(result.acceptedAmount)}');
    });
  }

  Future<void> _settleRound() async {
    final round = _round;
    if (round == null) {
      _toast('Start a round first.');
      return;
    }
    await _runBusy(() async {
      final result = await _api.settleTestRound(round.id);
      if (!mounted) return;
      setState(() {
        _lastResult = result;
        _tapIgnoredOverlay = false;
      });
      _toast('Round settled. Winner target: ${result.winningTargetId}');
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = _selectedGame;
    final targets = game?.targets ?? const <GameTarget>[];
    final bets = game?.allowedBets ?? const [400, 10000, 100000];

    return Scaffold(
      backgroundColor: const Color(0xFF080712),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080712),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Game Backend Test', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [IconButton(tooltip: 'Refresh catalog', onPressed: _loading ? null : _loadCatalog, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _HeroCard(game: game, round: _round),
              const SizedBox(height: 14),
              if (_error != null) _ErrorCard(message: _error!, onRetry: _loadCatalog),
              if (_error != null) const SizedBox(height: 14),
              _Card(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const _SectionTitle(title: 'Game Catalog', subtitle: 'Real /games/catalog, CDN enabled by backend config'),
                  const SizedBox(height: 10),
                  if (_games.isEmpty)
                    const Text('No games loaded yet.', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800))
                  else
                    DropdownButtonFormField<GameDefinition>(
                      initialValue: game,
                      dropdownColor: const Color(0xFF171425),
                      items: _games.map((item) => DropdownMenuItem(value: item, child: Text('${item.displayName} • v${item.configVersion}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)))).toList(),
                      onChanged: _loading
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() {
                                _selectedGame = value;
                                _round = null;
                                _lastBet = null;
                                _lastResult = null;
                                final valueTargets = value.targets;
                                _selectedTargetId = valueTargets.isEmpty ? null : valueTargets.first.id;
                                final valueBets = value.allowedBets;
                                _selectedAmount = valueBets.isEmpty ? 400 : valueBets.first;
                              });
                            },
                      decoration: _inputDecoration('Selected game'),
                    ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _ActionButton(label: 'Start Round', icon: Icons.play_arrow_rounded, onTap: _createRound, disabled: _loading || game == null)),
                    const SizedBox(width: 10),
                    Expanded(child: _ActionButton(label: 'Settle Test', icon: Icons.flag_rounded, onTap: _settleRound, disabled: _loading || _round == null)),
                  ]),
                ]),
              ),
              const SizedBox(height: 14),
              _Card(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const _SectionTitle(title: 'Choose Target', subtitle: 'Targets and multipliers come from backend/CDN-ready config'),
                  const SizedBox(height: 10),
                  if (targets.isEmpty)
                    const Text('No target config found for this game.', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800))
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: targets.map((target) {
                        final selected = _selectedTargetId == target.id;
                        return _TargetChip(target: target, selected: selected, onTap: () => setState(() => _selectedTargetId = target.id));
                      }).toList(),
                    ),
                ]),
              ),
              const SizedBox(height: 14),
              _Card(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const _SectionTitle(title: 'Bet Amount', subtitle: 'Backend can limit accepted amount without blocking the tap'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: bets.map((amount) {
                      final selected = _selectedAmount == amount;
                      return _AmountChip(amount: amount, selected: selected, onTap: () => setState(() => _selectedAmount = amount));
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(width: double.infinity, child: _ActionButton(label: 'Place Bet', icon: Icons.touch_app_rounded, onTap: _placeBet, disabled: _loading || _round == null)),
                ]),
              ),
              if (_lastBet != null) ...[
                const SizedBox(height: 14),
                _BetResultCard(result: _lastBet!),
              ],
              if (_lastResult != null) ...[
                const SizedBox(height: 14),
                _RoundResultCard(result: _lastResult!),
              ],
            ],
          ),
          if (_loading || _tapIgnoredOverlay)
            Positioned.fill(
              child: AbsorbPointer(
                child: Container(
                  color: Colors.black.withValues(alpha: _tapIgnoredOverlay ? 0.18 : 0.10),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(color: const Color(0xFF171425).withValues(alpha: 0.92), borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white.withValues(alpha: 0.12))),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.3, color: Color(0xFFFFD36A))),
                        const SizedBox(width: 12),
                        Text(_tapIgnoredOverlay ? 'Loading...' : 'Please wait...', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.game, required this.round});

  final GameDefinition? game;
  final GameRound? round;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF251538), Color(0xFF4A2A63), Color(0xFF0C0B18)]), borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: const Color(0xFF8C5CF6).withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 12))]),
      child: Row(children: [
        Container(width: 58, height: 58, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.casino_rounded, color: Color(0xFFFFD36A), size: 31)),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(game?.displayName ?? 'Backend Game', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(round == null ? 'Start a real backend round to test bets.' : 'Round #${round!.id} • ${round!.status} • Pool ${_format(round!.roundPoolAmount)}', style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 12.5, fontWeight: FontWeight.w800)),
        ])),
      ]),
    );
  }
}

class _BetResultCard extends StatelessWidget {
  const _BetResultCard({required this.result});

  final GameBetResult result;

  @override
  Widget build(BuildContext context) {
    final limited = result.wasLimited;
    return _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionTitle(title: result.shouldShowLoadingOverlay ? 'Tap Processing' : 'Bet Result', subtitle: result.message),
      const SizedBox(height: 10),
      _Line(label: 'Requested', value: _format(result.requestedAmount)),
      _Line(label: 'Accepted', value: _format(result.acceptedAmount), color: limited ? const Color(0xFFFFD36A) : const Color(0xFF12C7B7)),
      _Line(label: 'Wallet', value: _format(result.walletCoinBalance)),
      _Line(label: 'Risk', value: '${result.riskLevel} / ${result.riskScore}'),
      _Line(label: 'Action', value: result.riskAction),
    ]));
  }
}

class _RoundResultCard extends StatelessWidget {
  const _RoundResultCard({required this.result});

  final GameRoundResult result;

  @override
  Widget build(BuildContext context) {
    return _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionTitle(title: 'Round Result', subtitle: 'Server-side winner. Client cannot choose result.'),
      const SizedBox(height: 10),
      _Line(label: 'Winner', value: 'Target ${result.winningTargetId}'),
      _Line(label: 'Multiplier', value: '${result.multiplier}x'),
      _Line(label: 'Your bet', value: _format(result.totalUserBet)),
      _Line(label: 'Winnings', value: _format(result.totalUserWinnings), color: result.totalUserWinnings > 0 ? const Color(0xFF12C7B7) : Colors.white),
      _Line(label: 'Wallet', value: _format(result.walletCoinBalance)),
    ]));
  }
}

class _TargetChip extends StatelessWidget {
  const _TargetChip({required this.target, required this.selected, required this.onTap});

  final GameTarget target;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(19),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 104,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: selected ? const Color(0xFF8C5CF6) : const Color(0xFF171425), borderRadius: BorderRadius.circular(19), border: Border.all(color: selected ? const Color(0xFFFFD36A) : Colors.white.withValues(alpha: 0.10))),
        child: Column(children: [
          Text(target.emoji ?? '🎯', style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 5),
          Text(target.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text('${target.multiplier}x', style: const TextStyle(color: Color(0xFFFFD36A), fontSize: 11.5, fontWeight: FontWeight.w900)),
        ]),
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
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: selected ? const Color(0xFFFFD36A) : const Color(0xFF171425), borderRadius: BorderRadius.circular(999), border: Border.all(color: selected ? const Color(0xFFFFD36A) : Colors.white.withValues(alpha: 0.10))),
        child: Text(_format(amount), style: TextStyle(color: selected ? const Color(0xFF251538) : Colors.white, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.icon, required this.onTap, this.disabled = false});

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: disabled ? null : onTap,
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD36A), foregroundColor: const Color(0xFF251538), disabledBackgroundColor: Colors.white.withValues(alpha: 0.10), disabledForegroundColor: Colors.white38, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: const Color(0xFF100E1C), borderRadius: BorderRadius.circular(26), border: Border.all(color: Colors.white.withValues(alpha: 0.08))), child: child);
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 11.5, fontWeight: FontWeight.w700, height: 1.25))]);
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Expanded(child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w800))), Text(value, style: TextStyle(color: color ?? Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900))]));
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _Card(child: Row(children: [const Icon(Icons.error_outline_rounded, color: Color(0xFFE84C72)), const SizedBox(width: 10), Expanded(child: Text(message, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w800))), TextButton(onPressed: onRetry, child: const Text('Retry'))]));
}

InputDecoration _inputDecoration(String label) => InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w800), filled: true, fillColor: const Color(0xFF171425), border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFFFD36A))));

String _format(int value) {
  final sign = value < 0 ? '-' : '';
  final raw = value.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < raw.length; index++) {
    final reverseIndex = raw.length - index;
    buffer.write(raw[index]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) buffer.write(',');
  }
  return '$sign$buffer';
}
