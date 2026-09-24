import 'package:flutter/material.dart';

import 'package:vibematch_app/foundation/networking/app_network_client.dart';
import '../../auth/data/auth_api_service.dart';

class GamePropsPage extends StatefulWidget {
  const GamePropsPage({super.key});

  @override
  State<GamePropsPage> createState() => _GamePropsPageState();
}

class _GamePropsPageState extends State<GamePropsPage> {
  final _api = _GamePropsApi();

  bool _loading = true;
  bool _saving = false;
  bool _testingMode = false;
  String? _error;

  final _reason = TextEditingController(text: 'Super Owner Jungle Hunt props update');

  final _roundSeconds = TextEditingController();
  final _lockSeconds = TextEditingController();
  final _revealSeconds = TextEditingController();
  final _resultSeconds = TextEditingController();
  final _closeBettingLastSeconds = TextEditingController();

  final _maxTotalBetPerRound = TextEditingController();
  final _maxTargetsPerRound = TextEditingController();
  final _maxRoundLiability = TextEditingController();
  final _maxTargetLiability = TextEditingController();

  final _maxDailyLoss = TextEditingController();
  final _maxDailyBetVolume = TextEditingController();
  final _whaleDailyVolume = TextEditingController();
  final _whaleSingleBet = TextEditingController();
  final _whaleRecentBetCount = TextEditingController();

  final _rareBasketBps = TextEditingController();
  final _leftBasketWeight = TextEditingController();
  final _rightBasketWeight = TextEditingController();

  final List<_TargetWeightController> _targetWeights = <_TargetWeightController>[
    _TargetWeightController(0, 'Rabbit', 5),
    _TargetWeightController(1, 'Monkey', 5),
    _TargetWeightController(2, 'Wolf', 5),
    _TargetWeightController(3, 'Deer', 5),
    _TargetWeightController(4, 'Dragon', 10),
    _TargetWeightController(5, 'Panda', 15),
    _TargetWeightController(6, 'Eagle', 25),
    _TargetWeightController(7, 'Lion', 45),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.close();
    _reason.dispose();
    _roundSeconds.dispose();
    _lockSeconds.dispose();
    _revealSeconds.dispose();
    _resultSeconds.dispose();
    _closeBettingLastSeconds.dispose();
    _maxTotalBetPerRound.dispose();
    _maxTargetsPerRound.dispose();
    _maxRoundLiability.dispose();
    _maxTargetLiability.dispose();
    _maxDailyLoss.dispose();
    _maxDailyBetVolume.dispose();
    _whaleDailyVolume.dispose();
    _whaleSingleBet.dispose();
    _whaleRecentBetCount.dispose();
    _rareBasketBps.dispose();
    _leftBasketWeight.dispose();
    _rightBasketWeight.dispose();
    for (final item in _targetWeights) {
      item.controller.dispose();
    }
    super.dispose();
  }

  int _int(TextEditingController controller) => int.tryParse(controller.text.trim()) ?? 0;
  String _v(Object? value) => value?.toString() ?? '0';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final json = await _api.getProps();
      if (!mounted) return;

      setState(() {
        _testingMode = json['testing_mode_enabled'] == true;

        _roundSeconds.text = _v(json['round_seconds']);
        _lockSeconds.text = _v(json['lock_seconds']);
        _revealSeconds.text = _v(json['reveal_seconds']);
        _resultSeconds.text = _v(json['result_seconds']);
        _closeBettingLastSeconds.text = _v(json['close_betting_last_seconds']);

        _maxTotalBetPerRound.text = _v(json['max_total_bet_per_round']);
        _maxTargetsPerRound.text = _v(json['max_targets_per_user_round']);
        _maxRoundLiability.text = _v(json['max_round_liability']);
        _maxTargetLiability.text = _v(json['max_target_liability']);

        _maxDailyLoss.text = _v(json['max_daily_loss']);
        _maxDailyBetVolume.text = _v(json['max_daily_bet_volume']);
        _whaleDailyVolume.text = _v(json['whale_daily_volume']);
        _whaleSingleBet.text = _v(json['whale_single_bet']);
        _whaleRecentBetCount.text = _v(json['whale_recent_bet_count']);

        _rareBasketBps.text = _v(json['rare_basket_probability_basis_points']);
        _leftBasketWeight.text = _v(json['left_basket_weight']);
        _rightBasketWeight.text = _v(json['right_basket_weight']);

        final targets = json['target_weights'];
        if (targets is List) {
          for (final item in _targetWeights) {
            for (final raw in targets) {
              if (raw is Map && raw['target_id'] == item.targetId) {
                item.controller.text = _v(raw['weight']);
              }
            }
          }
        }

        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _applyTestingPreset() {
    setState(() {
      _testingMode = true;
      _reason.text = 'Enable Jungle Hunt testing mode';

      _roundSeconds.text = '30';
      _lockSeconds.text = '2';
      _revealSeconds.text = '15';
      _resultSeconds.text = '3';
      _closeBettingLastSeconds.text = '2';

      _maxTotalBetPerRound.text = '999000000';
      _maxTargetsPerRound.text = '6';
      _maxRoundLiability.text = '999000000';
      _maxTargetLiability.text = '999000000';

      _maxDailyLoss.text = '999000000';
      _maxDailyBetVolume.text = '999000000';
      _whaleDailyVolume.text = '999000000';
      _whaleSingleBet.text = '999000000';
      _whaleRecentBetCount.text = '999';

      _rareBasketBps.text = '120';
      _leftBasketWeight.text = '50';
      _rightBasketWeight.text = '50';

      for (final item in _targetWeights) {
        item.controller.text = '100';
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      await _api.saveProps(<String, dynamic>{
        'reason': _reason.text.trim().isEmpty ? 'Super Owner Jungle Hunt props update' : _reason.text.trim(),
        'testing_mode_enabled': _testingMode,
        'round_seconds': _int(_roundSeconds),
        'lock_seconds': _int(_lockSeconds),
        'reveal_seconds': _int(_revealSeconds),
        'result_seconds': _int(_resultSeconds),
        'close_betting_last_seconds': _int(_closeBettingLastSeconds),
        'max_total_bet_per_round': _int(_maxTotalBetPerRound),
        'max_targets_per_user_round': _int(_maxTargetsPerRound),
        'max_round_liability': _int(_maxRoundLiability),
        'max_target_liability': _int(_maxTargetLiability),
        'max_daily_loss': _int(_maxDailyLoss),
        'max_daily_bet_volume': _int(_maxDailyBetVolume),
        'whale_daily_volume': _int(_whaleDailyVolume),
        'whale_single_bet': _int(_whaleSingleBet),
        'whale_recent_bet_count': _int(_whaleRecentBetCount),
        'rare_basket_probability_basis_points': _int(_rareBasketBps),
        'left_basket_weight': _int(_leftBasketWeight),
        'right_basket_weight': _int(_rightBasketWeight),
        'target_weights': _targetWeights
            .map((item) => <String, dynamic>{
                  'target_id': item.targetId,
                  'label': item.label,
                  'multiplier': item.multiplier,
                  'weight': _int(item.controller),
                })
            .toList(growable: false),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jungle Hunt props saved.'), behavior: SnackBarBehavior.floating),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', '')), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F1),
        foregroundColor: const Color(0xFF251538),
        elevation: 0,
        title: const Text('Game Props', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFC857)))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
                  children: [
                    _hero(),
                    const SizedBox(height: 14),
                    _card(
                      'Jungle Hunt Testing',
                      Column(
                        children: [
                          SwitchListTile.adaptive(
                            value: _testingMode,
                            onChanged: (value) => setState(() => _testingMode = value),
                            title: Text(
                              _testingMode ? 'Testing Mode ON' : 'Testing Mode OFF',
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            subtitle: const Text('Use only for local testing. Turn OFF for production.'),
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _applyTestingPreset,
                              icon: const Icon(Icons.science_rounded),
                              label: const Text('Apply Testing Preset'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _card('Round Flow', Column(children: [
                      _field('Round seconds', _roundSeconds),
                      _field('Lock seconds', _lockSeconds),
                      _field('Reveal seconds', _revealSeconds),
                      _field('Result seconds', _resultSeconds),
                      _field('Close betting last seconds', _closeBettingLastSeconds),
                    ])),
                    _card('Exposure Controls', Column(children: [
                      _field('Max total bet per user per round', _maxTotalBetPerRound),
                      _field('Max targets per user round', _maxTargetsPerRound),
                      _field('Max round liability', _maxRoundLiability),
                      _field('Max target liability', _maxTargetLiability),
                    ])),
                    _card('Whale / Risk Controls', Column(children: [
                      _field('Max daily loss', _maxDailyLoss),
                      _field('Max daily bet volume', _maxDailyBetVolume),
                      _field('Whale daily volume', _whaleDailyVolume),
                      _field('Whale single bet', _whaleSingleBet),
                      _field('Whale recent bet count', _whaleRecentBetCount),
                    ])),
                    _card('Probability Controls', Column(children: [
                      _field('Rare basket probability bps', _rareBasketBps),
                      _field('Left basket weight', _leftBasketWeight),
                      _field('Right basket weight', _rightBasketWeight),
                      const SizedBox(height: 8),
                      ..._targetWeights.map((item) => _field('${item.label} ${item.multiplier}x weight', item.controller)),
                    ])),
                    _card('Audit Reason', _field('Reason', _reason, keyboard: TextInputType.text)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save_rounded),
                        label: Text(_saving ? 'Saving...' : 'Save Jungle Hunt Props', style: const TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(colors: [Color(0xFF120D1F), Color(0xFF4A2A63), Color(0xFFFFC857)]),
      ),
      child: const Text(
        'Game Props → Jungle Hunt',
        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _card(String title, Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEDE3D7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController controller, {TextInputType keyboard = TextInputType.number}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
      ),
    );
  }
}

class _TargetWeightController {
  _TargetWeightController(this.targetId, this.label, this.multiplier);
  final int targetId;
  final String label;
  final int multiplier;
  final TextEditingController controller = TextEditingController(text: '100');
}

class _GamePropsApi {
  _GamePropsApi({AppNetworkClient? apiClient, AuthApiService? authApiService})
      : _apiClient = apiClient ?? AppNetworkRuntime.shared,
        _authApiService = authApiService ?? const AuthApiService();

  final AppNetworkClient _apiClient;
  final AuthApiService _authApiService;

  Future<Map<String, dynamic>> getProps() {
    return _apiClient.getMap('/admin/games/props/jungle-hunt', headers: _headers());
  }

  Future<void> saveProps(Map<String, dynamic> body) async {
    await _apiClient.postMap('/admin/games/props/jungle-hunt', headers: _headers(), body: body);
  }

  Map<String, String> _headers() {
    final token = _authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Please login again before opening Game Props.');
    }
    return {'Authorization': 'Bearer $token'};
  }

  void close() => _apiClient.close();
}
