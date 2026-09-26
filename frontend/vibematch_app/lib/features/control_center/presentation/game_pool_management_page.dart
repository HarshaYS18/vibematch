import 'package:flutter/material.dart';

import 'package:vibematch_app/foundation/networking/app_network_client.dart';
import '../../auth/data/auth_api_service.dart';

class GamePoolManagementPage extends StatefulWidget {
  const GamePoolManagementPage({super.key});

  @override
  State<GamePoolManagementPage> createState() => _GamePoolManagementPageState();
}

class _GamePoolManagementPageState extends State<GamePoolManagementPage> {
  final _api = _GamePoolCpApi();

  List<GamePoolCpItem> _pools = const <GamePoolCpItem>[];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  GamePoolCpItem? get _mainPool {
    for (final pool in _pools) {
      if (_isMainPool(pool)) return pool;
    }
    return null;
  }

  List<GamePoolCpItem> get _gamePools =>
      _pools.where((pool) => !_isMainPool(pool)).toList(growable: false);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final pools = await _api.listPools();
      if (!mounted) return;
      setState(() {
        _pools = pools;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _clean(error);
      });
    }
  }

  String _clean(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  void _toast(String message, {bool danger = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              danger ? const Color(0xFFE84C72) : const Color(0xFF12C7B7),
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      );
  }

  Future<void> _run(
    Future<void> Function() action,
    String success,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      await action();
      if (!mounted) return;
      _toast(success);
      await _load();
    } catch (error) {
      if (!mounted) return;
      _toast(_clean(error), danger: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _closeSheetAndRun(
    Future<void> Function() action,
    String success,
  ) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _run(action, success);
    });
  }

  Future<void> _openTransferSheet({
    required GamePoolCpItem game,
    required bool addToGame,
  }) async {
    final main = _mainPool;
    if (main == null) {
      _toast('Main pool is unavailable. Refresh and try again.', danger: true);
      return;
    }

    final amount = TextEditingController();
    final gameName = _gameName(game.gameKey);
    final sourceAvailable =
        addToGame ? main.availableBalance : game.availableBalance;
    final from = addToGame ? 'Main Pool' : gameName;
    final to = addToGame ? gameName : 'Main Pool';

    await _showSheet(
      title: addToGame ? 'Add coins to $gameName' : 'Return coins to Main Pool',
      subtitle: '$from → $to',
      child: StatefulBuilder(
        builder: (context, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SimpleInfoCard(
              icon: Icons.account_balance_wallet_rounded,
              title: 'Available to move',
              value: _fmt(sourceAvailable),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              onChanged: (_) => setSheetState(() {}),
              decoration: _input(
                'How many coins?',
                helper: 'Enter an amount up to ${_fmt(sourceAvailable)}.',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _AmountChip(
                  label: '25%',
                  onTap: () {
                    amount.text = (sourceAvailable * 0.25).floor().toString();
                    setSheetState(() {});
                  },
                ),
                _AmountChip(
                  label: '50%',
                  onTap: () {
                    amount.text = (sourceAvailable * 0.50).floor().toString();
                    setSheetState(() {});
                  },
                ),
                _AmountChip(
                  label: '75%',
                  onTap: () {
                    amount.text = (sourceAvailable * 0.75).floor().toString();
                    setSheetState(() {});
                  },
                ),
                _AmountChip(
                  label: 'All',
                  onTap: () {
                    amount.text = sourceAvailable.toString();
                    setSheetState(() {});
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),
            _PrimaryButton(
              busy: _busy,
              icon: addToGame
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              label: addToGame ? 'Add coins' : 'Return coins',
              onPressed: () {
                final value = int.tryParse(amount.text.trim()) ?? 0;
                if (value <= 0) {
                  _toast('Enter a coin amount greater than zero.', danger: true);
                  return;
                }
                if (value > sourceAvailable) {
                  _toast(
                    'You can move at most ${_fmt(sourceAvailable)} coins.',
                    danger: true,
                  );
                  return;
                }

                final reason = addToGame
                    ? 'Admin added coins to ${game.gameKey} game pool'
                    : 'Admin returned coins from ${game.gameKey} game pool';

                _closeSheetAndRun(
                  () => addToGame
                      ? _api.allocate(
                          gameKey: game.gameKey,
                          amount: value,
                          reason: reason,
                        )
                      : _api.withdraw(
                          gameKey: game.gameKey,
                          amount: value,
                          reason: reason,
                        ),
                  addToGame
                      ? '${_fmt(value)} coins added to $gameName.'
                      : '${_fmt(value)} coins returned to Main Pool.',
                );
              },
            ),
          ],
        ),
      ),
    );

    amount.dispose();
  }

  Future<void> _openSettingsSheet(GamePoolCpItem pool) async {
    final dailyPayout =
        TextEditingController(text: pool.dailyPayoutCap.toString());
    final dailyLoss =
        TextEditingController(text: pool.dailyLossLimit.toString());
    final maxSingle =
        TextEditingController(text: pool.maxSinglePayout.toString());
    final rtpPercent = TextEditingController(
      text: _formatPercent(pool.rtpTargetBasisPoints / 100),
    );
    var status = pool.status;
    final gameName = _gameName(pool.gameKey);

    await _showSheet(
      title: 'Manage $gameName',
      subtitle: 'Simple safety controls for this game.',
      child: StatefulBuilder(
        builder: (context, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: status,
              decoration: _input(
                'Game status',
                helper: 'Pause a game without changing its money or limits.',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'ACTIVE',
                  child: Text('Running'),
                ),
                DropdownMenuItem(
                  value: 'FROZEN',
                  child: Text('Paused'),
                ),
                DropdownMenuItem(
                  value: 'CLOSED',
                  child: Text('Stopped'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setSheetState(() => status = value);
                }
              },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: dailyPayout,
              keyboardType: TextInputType.number,
              decoration: _input(
                'Daily payout limit',
                helper: 'Maximum coins this game can pay out in one day.',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: dailyLoss,
              keyboardType: TextInputType.number,
              decoration: _input(
                'Daily loss limit',
                helper: 'Safety limit for how much the pool can lose in one day.',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: maxSingle,
              keyboardType: TextInputType.number,
              decoration: _input(
                'Largest single win',
                helper: 'Maximum coins one player can win in one result.',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: rtpPercent,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: _input(
                'Target player return (%)',
                helper: 'Example: 85 means a target return of 85%.',
              ),
            ),
            const SizedBox(height: 14),
            const _HelpNote(
              text:
                  'Changes apply immediately and are automatically recorded in the admin audit log.',
            ),
            const SizedBox(height: 16),
            _PrimaryButton(
              busy: _busy,
              icon: Icons.check_circle_rounded,
              label: 'Save changes',
              onPressed: () {
                final payout = int.tryParse(dailyPayout.text.trim());
                final loss = int.tryParse(dailyLoss.text.trim());
                final maxWin = int.tryParse(maxSingle.text.trim());
                final rtp = double.tryParse(rtpPercent.text.trim());

                if (payout == null || payout < 0) {
                  _toast('Enter a valid daily payout limit.', danger: true);
                  return;
                }
                if (loss == null || loss < 0) {
                  _toast('Enter a valid daily loss limit.', danger: true);
                  return;
                }
                if (maxWin == null || maxWin < 0) {
                  _toast('Enter a valid largest single win.', danger: true);
                  return;
                }
                if (rtp == null || rtp < 0 || rtp > 100) {
                  _toast('Target player return must be from 0% to 100%.',
                      danger: true);
                  return;
                }

                _closeSheetAndRun(
                  () => _api.updateSettings(
                    gameKey: pool.gameKey,
                    poolType: pool.poolType,
                    status: status,
                    dailyPayoutCap: payout,
                    dailyLossLimit: loss,
                    maxSinglePayout: maxWin,
                    rtpTargetBasisPoints: (rtp * 100).round(),
                    reason: 'Admin updated ${pool.gameKey} game safety settings',
                  ),
                  '$gameName settings saved.',
                );
              },
            ),
          ],
        ),
      ),
    );

    dailyPayout.dispose();
    dailyLoss.dispose();
    maxSingle.dispose();
    rtpPercent.dispose();
  }

  InputDecoration _input(String label, {String? helper}) => InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 2,
        filled: true,
        fillColor: const Color(0xFFFFFCF8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE8DED3)),
        ),
      );

  Future<void> _showSheet({
    required String title,
    required String subtitle,
    required Widget child,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2D6C9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF251538),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF7B6A86),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final main = _mainPool;
    final games = _gamePools;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F1),
        foregroundColor: const Color(0xFF251538),
        elevation: 0,
        title: const Text(
          'Game Money',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFC857)),
            )
          : _error != null
              ? _GamePoolError(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  color: const Color(0xFFFFC857),
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                    children: [
                      const _PageIntro(),
                      const SizedBox(height: 14),
                      _MainPoolCard(pool: main),
                      const SizedBox(height: 20),
                      const Text(
                        'Games',
                        style: TextStyle(
                          color: Color(0xFF251538),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Add money, return money, or change safety limits.',
                        style: TextStyle(
                          color: Color(0xFF7B6A86),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (games.isEmpty)
                        const _EmptyGamesCard()
                      else
                        ...games.map(
                          (pool) => _SimpleGameCard(
                            pool: pool,
                            busy: _busy,
                            onAddCoins: () => _openTransferSheet(
                              game: pool,
                              addToGame: true,
                            ),
                            onReturnCoins: () => _openTransferSheet(
                              game: pool,
                              addToGame: false,
                            ),
                            onManage: () => _openSettingsSheet(pool),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _PageIntro extends StatelessWidget {
  const _PageIntro();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3CF),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFFFD76B)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_rounded, color: Color(0xFF9D6800)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Keep it simple: the Main Pool holds the money. Each game gets only the coins it needs. You can pause a game or change its limits at any time.',
                style: TextStyle(
                  color: Color(0xFF5D4311),
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
}

class _MainPoolCard extends StatelessWidget {
  const _MainPoolCard({required this.pool});

  final GamePoolCpItem? pool;

  @override
  Widget build(BuildContext context) {
    final value = pool;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [Color(0xFF1B1029), Color(0xFF4C2260)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF251538).withValues(alpha: 0.16),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CircleAvatar(
                backgroundColor: Color(0xFFFFC857),
                foregroundColor: Color(0xFF251538),
                child: Icon(Icons.account_balance_rounded),
              ),
              SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Main Pool',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Your central game money reserve',
                      style: TextStyle(
                        color: Color(0xFFD8C8E4),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Available',
            style: TextStyle(
              color: Color(0xFFD8C8E4),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value == null ? '--' : _fmt(value.availableBalance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (value != null && value.reservedBalance > 0) ...[
            const SizedBox(height: 6),
            Text(
              '${_fmt(value.reservedBalance)} currently reserved',
              style: const TextStyle(
                color: Color(0xFFD8C8E4),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SimpleGameCard extends StatelessWidget {
  const _SimpleGameCard({
    required this.pool,
    required this.busy,
    required this.onAddCoins,
    required this.onReturnCoins,
    required this.onManage,
  });

  final GamePoolCpItem pool;
  final bool busy;
  final VoidCallback onAddCoins;
  final VoidCallback onReturnCoins;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final running = pool.status == 'ACTIVE';
    final gameName = _gameName(pool.gameKey);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEDE3D7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    running ? const Color(0xFF12C7B7) : const Color(0xFFF2A93B),
                foregroundColor: Colors.white,
                child: Icon(
                  running
                      ? Icons.sports_esports_rounded
                      : Icons.pause_rounded,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gameName,
                      style: const TextStyle(
                        color: Color(0xFF251538),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    _StatusText(status: pool.status),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Available',
                    style: TextStyle(
                      color: Color(0xFF7B6A86),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _fmt(pool.availableBalance),
                    style: const TextStyle(
                      color: Color(0xFF251538),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.add_circle_outline_rounded,
                  label: 'Add coins',
                  onPressed: busy ? null : onAddCoins,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: Icons.keyboard_return_rounded,
                  label: 'Return coins',
                  onPressed: busy ? null : onReturnCoins,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: busy ? null : onManage,
              icon: const Icon(Icons.tune_rounded),
              label: const Text(
                'Manage game limits',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = _statusLabel(status);
    final running = status == 'ACTIVE';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: running ? const Color(0xFF12A795) : const Color(0xFFF2A93B),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF7B6A86),
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      );
}

class _AmountChip extends StatelessWidget {
  const _AmountChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ActionChip(
        onPressed: onTap,
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      );
}

class _SimpleInfoCard extends StatelessWidget {
  const _SimpleInfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF7F1),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFFFC857),
              foregroundColor: const Color(0xFF251538),
              child: Icon(icon),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF7B6A86),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF251538),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}

class _HelpNote extends StatelessWidget {
  const _HelpNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F8F6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 19,
              color: Color(0xFF138A7E),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Color(0xFF356A64),
                  fontSize: 11.5,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
}

class _EmptyGamesCard extends StatelessWidget {
  const _EmptyGamesCard();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFEDE3D7)),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.sports_esports_outlined,
              size: 36,
              color: Color(0xFF7B6A86),
            ),
            SizedBox(height: 8),
            Text(
              'No game pools yet',
              style: TextStyle(
                color: Color(0xFF251538),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}

class _GamePoolError extends StatelessWidget {
  const _GamePoolError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFE84C72),
                size: 44,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF251538),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.busy,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final bool busy;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          onPressed: busy ? null : onPressed,
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon),
          label: Text(
            busy ? 'Saving...' : label,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      );
}

class _GamePoolCpApi {
  _GamePoolCpApi({
    AppNetworkClient? apiClient,
    AuthApiService? authApiService,
  })  : _apiClient = apiClient ?? AppNetworkRuntime.shared,
        _authApiService = authApiService ?? const AuthApiService();

  final AppNetworkClient _apiClient;
  final AuthApiService _authApiService;

  Future<List<GamePoolCpItem>> listPools() async {
    final json = await _apiClient.getList(
      '/admin/games/pools',
      headers: _headers(),
    );
    return json
        .whereType<Map<String, dynamic>>()
        .map(GamePoolCpItem.fromJson)
        .toList(growable: false);
  }

  Future<void> allocate({
    required String gameKey,
    required int amount,
    required String reason,
  }) async =>
      _apiClient.postMap(
        '/admin/games/pools/allocate',
        headers: _headers(),
        body: {
          'game_key': gameKey,
          'amount': amount,
          'reason': reason,
        },
      );

  Future<void> withdraw({
    required String gameKey,
    required int amount,
    required String reason,
  }) async =>
      _apiClient.postMap(
        '/admin/games/pools/withdraw',
        headers: _headers(),
        body: {
          'game_key': gameKey,
          'amount': amount,
          'reason': reason,
        },
      );

  Future<void> updateSettings({
    required String gameKey,
    required String poolType,
    required String status,
    required int dailyPayoutCap,
    required int dailyLossLimit,
    required int maxSinglePayout,
    required int rtpTargetBasisPoints,
    required String reason,
  }) async =>
      _apiClient.postMap(
        '/admin/games/pools/settings',
        headers: _headers(),
        body: {
          'game_key': gameKey,
          'pool_type': poolType,
          'status': status,
          'daily_payout_cap': dailyPayoutCap,
          'daily_loss_limit': dailyLossLimit,
          'max_single_payout': maxSinglePayout,
          'rtp_target_basis_points': rtpTargetBasisPoints,
          'reason': reason,
        },
      );

  Map<String, String> _headers() {
    final token = _authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception(
        'Please login again before opening Game Money.',
      );
    }
    return {'Authorization': 'Bearer $token'};
  }

  void close() => _apiClient.close();
}

class GamePoolCpItem {
  const GamePoolCpItem({
    required this.id,
    required this.gameKey,
    required this.poolType,
    required this.balance,
    required this.reservedBalance,
    required this.availableBalance,
    required this.status,
    required this.dailyPayoutCap,
    required this.dailyLossLimit,
    required this.maxSinglePayout,
    required this.rtpTargetBasisPoints,
  });

  final int id;
  final String gameKey;
  final String poolType;
  final int balance;
  final int reservedBalance;
  final int availableBalance;
  final String status;
  final int dailyPayoutCap;
  final int dailyLossLimit;
  final int maxSinglePayout;
  final int rtpTargetBasisPoints;

  factory GamePoolCpItem.fromJson(Map<String, dynamic> json) => GamePoolCpItem(
        id: _int(json['id']),
        gameKey: json['game_key']?.toString() ?? '',
        poolType: json['pool_type']?.toString() ?? '',
        balance: _int(json['balance']),
        reservedBalance: _int(json['reserved_balance']),
        availableBalance: _int(json['available_balance']),
        status: json['status']?.toString() ?? 'ACTIVE',
        dailyPayoutCap: _int(json['daily_payout_cap']),
        dailyLossLimit: _int(json['daily_loss_limit']),
        maxSinglePayout: _int(json['max_single_payout']),
        rtpTargetBasisPoints: _int(json['rtp_target_basis_points']),
      );
}

bool _isMainPool(GamePoolCpItem pool) =>
    pool.gameKey.trim().toUpperCase() == 'GLOBAL';

String _gameName(String gameKey) {
  final normalized = gameKey.trim().toLowerCase();
  if (normalized == 'jackpot_king') return 'Jungle Hunt';
  if (normalized.isEmpty) return 'Game';

  return normalized
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _statusLabel(String status) {
  switch (status) {
    case 'ACTIVE':
      return 'Running';
    case 'FROZEN':
      return 'Paused';
    case 'CLOSED':
      return 'Stopped';
    default:
      return status;
  }
}

String _formatPercent(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

String _fmt(int value) {
  if (value >= 10000000) {
    return '${(value / 10000000).toStringAsFixed(value % 10000000 == 0 ? 0 : 1)}Cr';
  }
  if (value >= 100000) {
    return '${(value / 100000).toStringAsFixed(value % 100000 == 0 ? 0 : 1)}L';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
  }
  return value.toString();
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
