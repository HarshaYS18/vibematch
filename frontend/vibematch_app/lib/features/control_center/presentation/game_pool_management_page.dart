import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../auth/data/auth_api_service.dart';

class GamePoolManagementPage extends StatefulWidget {
  const GamePoolManagementPage({super.key});

  @override
  State<GamePoolManagementPage> createState() => _GamePoolManagementPageState();
}

class _GamePoolManagementPageState extends State<GamePoolManagementPage> {
  final _api = _GamePoolCpApi();

  List<GamePoolCpItem> _pools = const <GamePoolCpItem>[];
  GamePoolPair? _junglePair;
  bool _loading = true;
  bool _busy = false;
  String? _error;

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
      final jungle = await _api.getPoolPair('jackpot_king');
      if (!mounted) return;
      setState(() {
        _pools = pools;
        _junglePair = jungle;
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

  String _clean(Object error) => error.toString().replaceFirst('Exception: ', '');

  void _toast(String message, {bool danger = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: danger ? const Color(0xFFE84C72) : const Color(0xFF12C7B7),
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
      );
  }

  Future<void> _run(Future<void> Function() action, String success) async {
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


  void _closeSheetAndRun(Future<void> Function() action, String success) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _run(action, success);
    });
  }
  Future<void> _openTransferSheet({required bool allocate}) async {
    final amount = TextEditingController();
    final reason = TextEditingController(text: allocate ? 'Super Owner allocate to Jungle Hunt game pool' : 'Super Owner withdraw from Jungle Hunt game pool');
    await _showSheet(
      title: allocate ? 'Allocate to Jungle Hunt' : 'Withdraw to Main Pool',
      subtitle: allocate ? 'Move coins from Main Game House Pool to Jungle Hunt.' : 'Move available coins from Jungle Hunt back to Main Game House Pool.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: amount, keyboardType: TextInputType.number, decoration: _input('Coin amount')),
          const SizedBox(height: 12),
          TextField(controller: reason, minLines: 2, maxLines: 3, decoration: _input('Reason')),
          const SizedBox(height: 14),
          _PrimaryButton(
            busy: _busy,
            icon: allocate ? Icons.call_made_rounded : Icons.call_received_rounded,
            label: allocate ? 'Allocate' : 'Withdraw',
            onPressed: () {
              final value = int.tryParse(amount.text.trim()) ?? 0;
              final safeReason = reason.text.trim();
              if (value <= 0 || safeReason.length < 3) return _toast('Amount and reason are required.', danger: true);
              _closeSheetAndRun(
                () => allocate ? _api.allocate(gameKey: 'jackpot_king', amount: value, reason: safeReason) : _api.withdraw(gameKey: 'jackpot_king', amount: value, reason: safeReason),
                allocate ? 'Allocated to Jungle Hunt pool.' : 'Withdrawn to Main pool.',
              );
            },
          ),
        ],
      ),
    );
    amount.dispose();
    reason.dispose();
  }

  Future<void> _openAdjustSheet(GamePoolCpItem pool) async {
    final amount = TextEditingController();
    final reason = TextEditingController(text: 'Super Owner direct game pool adjustment');
    var direction = 'CREDIT';
    await _showSheet(
      title: 'Adjust ${pool.gameKey}',
      subtitle: 'Direct manual adjustment. Prefer Allocate/Withdraw for main↔game movement.',
      child: StatefulBuilder(
        builder: (context, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: direction,
              decoration: _input('Direction'),
              items: const [
                DropdownMenuItem(value: 'CREDIT', child: Text('Credit / Add')),
                DropdownMenuItem(value: 'DEBIT', child: Text('Debit / Remove')),
              ],
              onChanged: (value) {
                if (value != null) setSheetState(() => direction = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(controller: amount, keyboardType: TextInputType.number, decoration: _input('Coin amount')),
            const SizedBox(height: 12),
            TextField(controller: reason, minLines: 2, maxLines: 3, decoration: _input('Reason')),
            const SizedBox(height: 14),
            _PrimaryButton(
              busy: _busy,
              icon: Icons.tune_rounded,
              label: 'Apply adjustment',
              onPressed: () {
                final value = int.tryParse(amount.text.trim()) ?? 0;
                final safeReason = reason.text.trim();
                if (value <= 0 || safeReason.length < 3) return _toast('Amount and reason are required.', danger: true);
                _closeSheetAndRun(
                  () => _api.adjust(gameKey: pool.gameKey, poolType: pool.poolType, direction: direction, amount: value, reason: safeReason),
                  'Game pool adjusted and audit logged.',
                );
              },
            ),
          ],
        ),
      ),
    );
    amount.dispose();
    reason.dispose();
  }

  Future<void> _openSettingsSheet(GamePoolCpItem pool) async {
    final dailyPayout = TextEditingController(text: pool.dailyPayoutCap.toString());
    final dailyLoss = TextEditingController(text: pool.dailyLossLimit.toString());
    final maxSingle = TextEditingController(text: pool.maxSinglePayout.toString());
    final rtp = TextEditingController(text: pool.rtpTargetBasisPoints.toString());
    final reason = TextEditingController(text: 'Super Owner game pool risk settings update');
    var status = pool.status;
    await _showSheet(
      title: 'Pool settings',
      subtitle: '${pool.gameKey} • ${pool.poolType}',
      child: StatefulBuilder(
        builder: (context, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: status,
              decoration: _input('Status'),
              items: const [
                DropdownMenuItem(value: 'ACTIVE', child: Text('ACTIVE')),
                DropdownMenuItem(value: 'FROZEN', child: Text('FROZEN')),
                DropdownMenuItem(value: 'CLOSED', child: Text('CLOSED')),
              ],
              onChanged: (value) {
                if (value != null) setSheetState(() => status = value);
              },
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: dailyPayout, keyboardType: TextInputType.number, decoration: _input('Daily payout cap'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: dailyLoss, keyboardType: TextInputType.number, decoration: _input('Daily loss limit'))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: maxSingle, keyboardType: TextInputType.number, decoration: _input('Max single payout'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: rtp, keyboardType: TextInputType.number, decoration: _input('RTP bps'))),
            ]),
            const SizedBox(height: 12),
            TextField(controller: reason, minLines: 2, maxLines: 3, decoration: _input('Reason')),
            const SizedBox(height: 14),
            _PrimaryButton(
              busy: _busy,
              icon: Icons.save_rounded,
              label: 'Save settings',
              onPressed: () {
                final safeReason = reason.text.trim();
                if (safeReason.length < 3) return _toast('Reason is required.', danger: true);
                _closeSheetAndRun(
                  () => _api.updateSettings(
                    gameKey: pool.gameKey,
                    poolType: pool.poolType,
                    status: status,
                    dailyPayoutCap: int.tryParse(dailyPayout.text.trim()) ?? pool.dailyPayoutCap,
                    dailyLossLimit: int.tryParse(dailyLoss.text.trim()) ?? pool.dailyLossLimit,
                    maxSinglePayout: int.tryParse(maxSingle.text.trim()) ?? pool.maxSinglePayout,
                    rtpTargetBasisPoints: int.tryParse(rtp.text.trim()) ?? pool.rtpTargetBasisPoints,
                    reason: safeReason,
                  ),
                  'Game pool settings updated.',
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
    rtp.dispose();
    reason.dispose();
  }

  InputDecoration _input(String label) => InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)));

  Future<void> _showSheet({required String title, required String subtitle, required Widget child}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: SafeArea(top: false, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: const Color(0xFFE2D6C9), borderRadius: BorderRadius.circular(999)))),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            child,
          ]))),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pair = _junglePair;
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F1),
        foregroundColor: const Color(0xFF251538),
        elevation: 0,
        title: const Text('Game Pool Management', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFC857)))
          : _error != null
              ? _GamePoolError(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  color: const Color(0xFFFFC857),
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                    children: [
                      _HeroPoolCard(pair: pair),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(child: _SmallPoolButton(icon: Icons.call_made_rounded, title: 'Allocate', subtitle: 'Main → Jungle', onTap: () => _openTransferSheet(allocate: true))),
                        const SizedBox(width: 10),
                        Expanded(child: _SmallPoolButton(icon: Icons.call_received_rounded, title: 'Withdraw', subtitle: 'Jungle → Main', onTap: () => _openTransferSheet(allocate: false))),
                      ]),
                      const SizedBox(height: 14),
                      const _GamePoolSectionHeader(title: 'All game pools', subtitle: 'Super Owner adjustable'),
                      const SizedBox(height: 10),
                      ..._pools.map((pool) => _GamePoolCard(pool: pool, onAdjust: () => _openAdjustSheet(pool), onSettings: () => _openSettingsSheet(pool))),
                    ],
                  ),
                ),
    );
  }
}

class _HeroPoolCard extends StatelessWidget {
  const _HeroPoolCard({required this.pair});
  final GamePoolPair? pair;
  @override
  Widget build(BuildContext context) {
    final main = pair?.mainPool;
    final game = pair?.gamePool;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), gradient: const LinearGradient(colors: [Color(0xFF120D1F), Color(0xFF3A194D), Color(0xFFFFC857)]), boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.18), blurRadius: 22, offset: const Offset(0, 12))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Icon(Icons.account_balance_rounded, color: Color(0xFFFFF0A8), size: 28), SizedBox(width: 9), Expanded(child: Text('Production Game House Pools', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)))]),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: _HeroMetric(label: 'Main Available', value: main == null ? '--' : _fmt(main.availableBalance))), const SizedBox(width: 10), Expanded(child: _HeroMetric(label: 'Jungle Available', value: game == null ? '--' : _fmt(game.availableBalance)))]),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: _HeroMetric(label: 'Main Reserved', value: main == null ? '--' : _fmt(main.reservedBalance))), const SizedBox(width: 10), Expanded(child: _HeroMetric(label: 'Jungle Reserved', value: game == null ? '--' : _fmt(game.reservedBalance)))]),
      ]),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withValues(alpha: 0.18))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.74), fontSize: 11, fontWeight: FontWeight.w800)), const SizedBox(height: 5), Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900))]));
}

class _SmallPoolButton extends StatelessWidget {
  const _SmallPoolButton({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(22), child: Ink(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFEDE3D7))), child: Row(children: [CircleAvatar(backgroundColor: const Color(0xFFFFC857), foregroundColor: const Color(0xFF251538), child: Icon(icon)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 13, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(subtitle, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11, fontWeight: FontWeight.w700))]))])));
}

class _GamePoolCard extends StatelessWidget {
  const _GamePoolCard({required this.pool, required this.onAdjust, required this.onSettings});
  final GamePoolCpItem pool;
  final VoidCallback onAdjust;
  final VoidCallback onSettings;
  @override
  Widget build(BuildContext context) {
    final frozen = pool.status != 'ACTIVE';
    return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: frozen ? const Color(0xFFE84C72).withValues(alpha: 0.30) : const Color(0xFFEDE3D7))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [CircleAvatar(backgroundColor: frozen ? const Color(0xFFE84C72) : const Color(0xFF12C7B7), foregroundColor: Colors.white, child: Icon(frozen ? Icons.pause_circle_rounded : Icons.sports_esports_rounded)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(pool.gameKey, style: const TextStyle(color: Color(0xFF251538), fontSize: 15, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text('${pool.poolType} • ${pool.status}', style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w800))])), Text(_fmt(pool.availableBalance), style: const TextStyle(color: Color(0xFF251538), fontSize: 14, fontWeight: FontWeight.w900))]),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [_PoolPill(label: 'Balance', value: _fmt(pool.balance)), _PoolPill(label: 'Reserved', value: _fmt(pool.reservedBalance)), _PoolPill(label: 'Daily cap', value: _fmt(pool.dailyPayoutCap)), _PoolPill(label: 'Loss limit', value: _fmt(pool.dailyLossLimit)), _PoolPill(label: 'Max payout', value: _fmt(pool.maxSinglePayout)), _PoolPill(label: 'RTP', value: '${pool.rtpTargetBasisPoints} bps')]),
      const SizedBox(height: 12),
      Row(children: [Expanded(child: OutlinedButton.icon(onPressed: onAdjust, icon: const Icon(Icons.tune_rounded), label: const Text('Adjust'))), const SizedBox(width: 10), Expanded(child: ElevatedButton.icon(onPressed: onSettings, icon: const Icon(Icons.settings_rounded), label: const Text('Settings')))]),
    ]));
  }
}

class _PoolPill extends StatelessWidget {
  const _PoolPill({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7), decoration: BoxDecoration(color: const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(999)), child: Text('$label: $value', style: const TextStyle(color: Color(0xFF251538), fontSize: 11, fontWeight: FontWeight.w800)));
}

class _GamePoolSectionHeader extends StatelessWidget {
  const _GamePoolSectionHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Row(children: [Expanded(child: Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 16, fontWeight: FontWeight.w900))), Text(subtitle, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w800))]);
}

class _GamePoolError extends StatelessWidget {
  const _GamePoolError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(18), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline_rounded, color: Color(0xFFE84C72), size: 44), const SizedBox(height: 10), Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w800)), const SizedBox(height: 12), FilledButton(onPressed: onRetry, child: const Text('Retry'))])));
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.busy, required this.icon, required this.label, required this.onPressed});
  final bool busy;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(width: double.infinity, height: 50, child: FilledButton.icon(onPressed: busy ? null : onPressed, icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(icon), label: Text(busy ? 'Saving...' : label, style: const TextStyle(fontWeight: FontWeight.w900))));
}

class _GamePoolCpApi {
  _GamePoolCpApi({ApiClient? apiClient, AuthApiService? authApiService}) : _apiClient = apiClient ?? ApiClient(), _authApiService = authApiService ?? const AuthApiService();
  final ApiClient _apiClient;
  final AuthApiService _authApiService;
  Future<List<GamePoolCpItem>> listPools() async {
    final json = await _apiClient.getList('/super-owner/game-pools', headers: _headers());
    return json.whereType<Map<String, dynamic>>().map(GamePoolCpItem.fromJson).toList(growable: false);
  }
  Future<GamePoolPair> getPoolPair(String gameKey) async {
    final json = await _apiClient.getMap('/super-owner/game-pools/$gameKey', headers: _headers());
    return GamePoolPair.fromJson(json);
  }
  Future<void> allocate({required String gameKey, required int amount, required String reason}) async => _apiClient.postMap('/super-owner/game-pools/allocate', headers: _headers(), body: {'game_key': gameKey, 'amount': amount, 'reason': reason});
  Future<void> withdraw({required String gameKey, required int amount, required String reason}) async => _apiClient.postMap('/super-owner/game-pools/withdraw', headers: _headers(), body: {'game_key': gameKey, 'amount': amount, 'reason': reason});
  Future<void> adjust({required String gameKey, required String poolType, required String direction, required int amount, required String reason}) async => _apiClient.postMap('/super-owner/game-pools/adjust', headers: _headers(), body: {'game_key': gameKey, 'pool_type': poolType, 'direction': direction, 'amount': amount, 'reason': reason});
  Future<void> updateSettings({required String gameKey, required String poolType, required String status, required int dailyPayoutCap, required int dailyLossLimit, required int maxSinglePayout, required int rtpTargetBasisPoints, required String reason}) async => _apiClient.postMap('/super-owner/game-pools/settings', headers: _headers(), body: {'game_key': gameKey, 'pool_type': poolType, 'status': status, 'daily_payout_cap': dailyPayoutCap, 'daily_loss_limit': dailyLossLimit, 'max_single_payout': maxSinglePayout, 'rtp_target_basis_points': rtpTargetBasisPoints, 'reason': reason});
  Map<String, String> _headers() {
    final token = _authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) throw Exception('Please login again before opening Game Pool Management.');
    return {'Authorization': 'Bearer $token'};
  }
  void close() => _apiClient.close();
}

class GamePoolPair {
  const GamePoolPair({required this.mainPool, required this.gamePool});
  final GamePoolCpItem mainPool;
  final GamePoolCpItem gamePool;
  factory GamePoolPair.fromJson(Map<String, dynamic> json) => GamePoolPair(mainPool: GamePoolCpItem.fromJson(Map<String, dynamic>.from(json['main_pool'] as Map)), gamePool: GamePoolCpItem.fromJson(Map<String, dynamic>.from(json['game_pool'] as Map)));
}

class GamePoolCpItem {
  const GamePoolCpItem({required this.id, required this.gameKey, required this.poolType, required this.balance, required this.reservedBalance, required this.availableBalance, required this.status, required this.dailyPayoutCap, required this.dailyLossLimit, required this.maxSinglePayout, required this.rtpTargetBasisPoints});
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
  factory GamePoolCpItem.fromJson(Map<String, dynamic> json) => GamePoolCpItem(id: _int(json['id']), gameKey: json['game_key']?.toString() ?? '', poolType: json['pool_type']?.toString() ?? '', balance: _int(json['balance']), reservedBalance: _int(json['reserved_balance']), availableBalance: _int(json['available_balance']), status: json['status']?.toString() ?? 'ACTIVE', dailyPayoutCap: _int(json['daily_payout_cap']), dailyLossLimit: _int(json['daily_loss_limit']), maxSinglePayout: _int(json['max_single_payout']), rtpTargetBasisPoints: _int(json['rtp_target_basis_points']));
}

String _fmt(int value) {
  if (value >= 10000000) return '${(value / 10000000).toStringAsFixed(value % 10000000 == 0 ? 0 : 1)}Cr';
  if (value >= 100000) return '${(value / 100000).toStringAsFixed(value % 100000 == 0 ? 0 : 1)}L';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
  return value.toString();
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

