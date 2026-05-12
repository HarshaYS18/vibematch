import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../live_room_models.dart';
import '../widgets/room_theme.dart';
import 'cricket_mode_module.dart';

class CricketRoomRules {
  const CricketRoomRules._();

  static const String fixedLayoutId = '5x2';
  static const int totalSeats = 10;
  static const int scorerSeatIndex = 2;
  static const double scorerOverlayHeightFactor = 0.50;

  static bool isScorerSeat(int seatIndex) => seatIndex == scorerSeatIndex;

  static int currentUserSeatIndex({
    required List<RoomSeat> seats,
    required String currentUserId,
  }) {
    return seats.indexWhere((seat) => seat.user?.id == currentUserId);
  }

  static bool canUserScore({
    required List<RoomSeat> seats,
    required String currentUserId,
  }) {
    return currentUserSeatIndex(
          seats: seats,
          currentUserId: currentUserId,
        ) ==
        scorerSeatIndex;
  }
}

enum CricketTournamentType {
  knockout,
  league,
  roundRobin,
  doubleRoundRobin,
  groupStageKnockout,
}

class CricketTournamentRules {
  const CricketTournamentRules({
    required this.playersPerTeam,
    required this.oversPerInnings,
    required this.wicketsPerInnings,
    required this.ballsPerOver,
    required this.matchesPerTeam,
    required this.matchesAgainstEachTeam,
    required this.winPoints,
    required this.tiePoints,
    required this.noResultPoints,
    required this.qualifierCount,
    required this.type,
    this.enableNetRunRate = true,
    this.enableBonusPoint = false,
    this.enableSuperOver = false,
    this.enableLastManStands = false,
    this.enableThirdPlaceMatch = false,
  });

  final int playersPerTeam;
  final int oversPerInnings;
  final int wicketsPerInnings;
  final int ballsPerOver;
  final int matchesPerTeam;
  final int matchesAgainstEachTeam;
  final int winPoints;
  final int tiePoints;
  final int noResultPoints;
  final int qualifierCount;
  final CricketTournamentType type;
  final bool enableNetRunRate;
  final bool enableBonusPoint;
  final bool enableSuperOver;
  final bool enableLastManStands;
  final bool enableThirdPlaceMatch;

  factory CricketTournamentRules.t10League() {
    return const CricketTournamentRules(
      playersPerTeam: 11,
      oversPerInnings: 10,
      wicketsPerInnings: 10,
      ballsPerOver: 6,
      matchesPerTeam: 3,
      matchesAgainstEachTeam: 1,
      winPoints: 2,
      tiePoints: 1,
      noResultPoints: 1,
      qualifierCount: 4,
      type: CricketTournamentType.league,
      enableNetRunRate: true,
      enableBonusPoint: false,
      enableSuperOver: true,
    );
  }

  CricketTournamentRules copyWith({
    int? playersPerTeam,
    int? oversPerInnings,
    int? wicketsPerInnings,
    int? ballsPerOver,
    int? matchesPerTeam,
    int? matchesAgainstEachTeam,
    int? winPoints,
    int? tiePoints,
    int? noResultPoints,
    int? qualifierCount,
    CricketTournamentType? type,
    bool? enableNetRunRate,
    bool? enableBonusPoint,
    bool? enableSuperOver,
    bool? enableLastManStands,
    bool? enableThirdPlaceMatch,
  }) {
    return CricketTournamentRules(
      playersPerTeam: playersPerTeam ?? this.playersPerTeam,
      oversPerInnings: oversPerInnings ?? this.oversPerInnings,
      wicketsPerInnings: wicketsPerInnings ?? this.wicketsPerInnings,
      ballsPerOver: ballsPerOver ?? this.ballsPerOver,
      matchesPerTeam: matchesPerTeam ?? this.matchesPerTeam,
      matchesAgainstEachTeam:
          matchesAgainstEachTeam ?? this.matchesAgainstEachTeam,
      winPoints: winPoints ?? this.winPoints,
      tiePoints: tiePoints ?? this.tiePoints,
      noResultPoints: noResultPoints ?? this.noResultPoints,
      qualifierCount: qualifierCount ?? this.qualifierCount,
      type: type ?? this.type,
      enableNetRunRate: enableNetRunRate ?? this.enableNetRunRate,
      enableBonusPoint: enableBonusPoint ?? this.enableBonusPoint,
      enableSuperOver: enableSuperOver ?? this.enableSuperOver,
      enableLastManStands: enableLastManStands ?? this.enableLastManStands,
      enableThirdPlaceMatch:
          enableThirdPlaceMatch ?? this.enableThirdPlaceMatch,
    );
  }
}

class CricketTournamentConfig {
  const CricketTournamentConfig({
    required this.name,
    required this.teams,
    required this.rules,
  });

  final String name;
  final List<String> teams;
  final CricketTournamentRules rules;

  factory CricketTournamentConfig.demo() {
    return CricketTournamentConfig(
      name: 'Vibe Premier Cup',
      teams: const ['Vibe Strikers', 'Royal Hitters', 'Neon Kings', 'Aqua Titans'],
      rules: CricketTournamentRules.t10League(),
    );
  }
}

class CricketPointsRow {
  const CricketPointsRow({
    required this.teamName,
    this.played = 0,
    this.won = 0,
    this.lost = 0,
    this.tied = 0,
    this.noResult = 0,
    this.points = 0,
    this.runsFor = 0,
    this.ballsFaced = 0,
    this.runsAgainst = 0,
    this.ballsBowled = 0,
    this.wicketsLost = 0,
    this.wicketsTaken = 0,
    this.form = '',
  });

  final String teamName;
  final int played;
  final int won;
  final int lost;
  final int tied;
  final int noResult;
  final int points;
  final int runsFor;
  final int ballsFaced;
  final int runsAgainst;
  final int ballsBowled;
  final int wicketsLost;
  final int wicketsTaken;
  final String form;

  double get netRunRate => CricketMath.netRunRate(
        runsFor: runsFor,
        ballsFaced: ballsFaced,
        runsAgainst: runsAgainst,
        ballsBowled: ballsBowled,
      );
}

class CricketMath {
  const CricketMath._();

  static double runRate({
    required int runs,
    required int legalBalls,
    int ballsPerOver = 6,
  }) {
    if (legalBalls <= 0 || ballsPerOver <= 0) return 0;
    return runs / (legalBalls / ballsPerOver);
  }

  static double requiredRunRate({
    required int target,
    required int currentRuns,
    required int ballsRemaining,
    int ballsPerOver = 6,
  }) {
    if (ballsRemaining <= 0 || target <= currentRuns) return 0;
    return (target - currentRuns) / (ballsRemaining / ballsPerOver);
  }

  static double netRunRate({
    required int runsFor,
    required int ballsFaced,
    required int runsAgainst,
    required int ballsBowled,
    int ballsPerOver = 6,
  }) {
    return runRate(
          runs: runsFor,
          legalBalls: ballsFaced,
          ballsPerOver: ballsPerOver,
        ) -
        runRate(
          runs: runsAgainst,
          legalBalls: ballsBowled,
          ballsPerOver: ballsPerOver,
        );
  }

  static String oversText(int legalBalls, {int ballsPerOver = 6}) {
    if (legalBalls <= 0) return '0.0';
    return '${legalBalls ~/ ballsPerOver}.${legalBalls % ballsPerOver}';
  }

  static int ballsFromOvers({required int overs, int ballsPerOver = 6}) {
    return math.max(0, overs * ballsPerOver);
  }
}

class CricketRoomModeController extends ChangeNotifier {
  CricketRoomModeController({
    required String roomId,
    required String roomName,
  }) : scorer = CricketModeController(roomId: roomId, roomName: roomName);

  final CricketModeController scorer;
  CricketTournamentConfig tournament = CricketTournamentConfig.demo();
  bool _active = false;
  String? _previousLayoutId;
  RoomBackgroundTheme? _previousBackground;

  bool get active => _active;
  String? get previousLayoutId => _previousLayoutId;
  RoomBackgroundTheme? get previousBackground => _previousBackground;
  CricketMatchState get match => scorer.state;
  CricketScoreSnapshot get snapshot => scorer.state.snapshot;

  void startRoomMode({
    required String currentLayoutId,
    required RoomBackgroundTheme currentBackground,
  }) {
    _previousLayoutId ??= currentLayoutId;
    _previousBackground ??= currentBackground;
    _active = true;
    scorer.startMatch();
    notifyListeners();
  }

  void endRoomMode() {
    _active = false;
    scorer.complete();
    notifyListeners();
  }

  void updateTournament(CricketTournamentConfig value) {
    tournament = value;
    notifyListeners();
  }

  void addRuns(int runs) {
    scorer.addRuns(runs);
    notifyListeners();
  }

  void addExtra(CricketExtraType type, int runs) {
    scorer.addExtra(type, runs);
    notifyListeners();
  }

  void addWicket(CricketWicketType type) {
    scorer.addWicket(type);
    notifyListeners();
  }

  void undo() {
    scorer.undo();
    notifyListeners();
  }

  void endInnings() {
    scorer.endInnings();
    notifyListeners();
  }

  void startSecondInnings() {
    scorer.startSecondInnings();
    notifyListeners();
  }

  @override
  void dispose() {
    scorer.dispose();
    super.dispose();
  }
}

class CricketRoomModeModule {
  const CricketRoomModeModule._();

  static bool canScore({
    required List<RoomSeat> seats,
    required String currentUserId,
  }) {
    return CricketRoomRules.canUserScore(
      seats: seats,
      currentUserId: currentUserId,
    );
  }

  static Widget fixedScoreboard({
    required CricketMatchState state,
    EdgeInsetsGeometry margin = EdgeInsets.zero,
  }) {
    return CricketFixedScoreboard(state: state, margin: margin);
  }

  static Widget scorerOverlay({
    required CricketRoomModeController controller,
    required bool visibleToCurrentUser,
  }) {
    if (!visibleToCurrentUser) return const SizedBox.shrink();
    return CricketScorerHalfOverlay(controller: controller);
  }

  static Future<CricketTournamentConfig?> openTournamentCreator({
    required BuildContext context,
    CricketTournamentConfig? initialConfig,
  }) {
    return showModalBottomSheet<CricketTournamentConfig>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CricketTournamentCreatorSheet(
        initialConfig: initialConfig ?? CricketTournamentConfig.demo(),
      ),
    );
  }

  static Future<void> openPointsTable({
    required BuildContext context,
    required List<CricketPointsRow> rows,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CricketPointsTableSheet(rows: rows),
    );
  }
}

class CricketFixedScoreboard extends StatelessWidget {
  const CricketFixedScoreboard({
    super.key,
    required this.state,
    this.margin = EdgeInsets.zero,
  });

  final CricketMatchState state;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final snapshot = state.snapshot;
    final target = state.targetRuns;
    final ballsRemaining = math.max(
      0,
      CricketMath.ballsFromOvers(overs: state.oversLimit) - snapshot.legalBalls,
    );
    final requiredRate = target == null
        ? null
        : CricketMath.requiredRunRate(
            target: target,
            currentRuns: snapshot.runs,
            ballsRemaining: ballsRemaining,
          );

    return Container(
      margin: margin,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xEE061B0D), Color(0xEE0E5A31)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.sports_cricket_rounded, color: Color(0xFF86FF9D), size: 17),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${state.battingTeam.shortName} ${snapshot.runs}/${snapshot.wickets} (${snapshot.oversText})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              Text(
                'CRR ${snapshot.currentRunRate.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFFFFD36A),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            target == null
                ? '${state.battingTeam.name} batting • Scorer seat: 3'
                : 'Target $target • Need ${math.max(0, target - snapshot.runs)} from $ballsRemaining balls${requiredRate == null ? '' : ' • RRR ${requiredRate.toStringAsFixed(2)}'}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (snapshot.recentBalls.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: snapshot.recentBalls
                  .map((ball) => _CricketMiniBallChip(label: ball))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class CricketScorerHalfOverlay extends StatelessWidget {
  const CricketScorerHalfOverlay({
    super.key,
    required this.controller,
  });

  final CricketRoomModeController controller;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: CricketRoomRules.scorerOverlayHeightFactor,
        widthFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF9F8F2),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.34),
                blurRadius: 28,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(
                children: [
                  const SheetHandle(width: 42),
                  const SizedBox(height: 8),
                  _ScorerOverlayHeader(state: controller.match),
                  const SizedBox(height: 10),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 4,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.68,
                      padding: EdgeInsets.zero,
                      children: [
                        for (final run in const [0, 1, 2, 3, 4, 5, 6])
                          _PremiumScoreButton(
                            label: '$run',
                            onTap: () => controller.addRuns(run),
                          ),
                        _PremiumScoreButton(
                          label: 'Wd',
                          onTap: () => controller.addExtra(CricketExtraType.wide, 1),
                        ),
                        _PremiumScoreButton(
                          label: 'Nb',
                          onTap: () => controller.addExtra(CricketExtraType.noBall, 1),
                        ),
                        _PremiumScoreButton(
                          label: 'Bye',
                          onTap: () => controller.addExtra(CricketExtraType.bye, 1),
                        ),
                        _PremiumScoreButton(
                          label: 'LB',
                          onTap: () => controller.addExtra(CricketExtraType.legBye, 1),
                        ),
                        _PremiumScoreButton(
                          label: 'Wicket',
                          danger: true,
                          onTap: () => controller.addWicket(CricketWicketType.bowled),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: controller.undo,
                          icon: const Icon(Icons.undo_rounded, size: 17),
                          label: const Text('Undo'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: controller.endInnings,
                          icon: const Icon(Icons.flag_rounded, size: 17),
                          label: const Text('End innings'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CricketTournamentCreatorSheet extends StatefulWidget {
  const CricketTournamentCreatorSheet({
    super.key,
    required this.initialConfig,
  });

  final CricketTournamentConfig initialConfig;

  @override
  State<CricketTournamentCreatorSheet> createState() =>
      _CricketTournamentCreatorSheetState();
}

class _CricketTournamentCreatorSheetState
    extends State<CricketTournamentCreatorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _teamsController;
  late CricketTournamentRules _rules;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialConfig.name);
    _teamsController = TextEditingController(
      text: widget.initialConfig.teams.join('\n'),
    );
    _rules = widget.initialConfig.rules;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _teamsController.dispose();
    super.dispose();
  }

  List<String> get _teams => _teamsController.text
      .split('\n')
      .map((team) => team.trim())
      .where((team) => team.isNotEmpty)
      .toList(growable: false);

  void _save() {
    Navigator.pop(
      context,
      CricketTournamentConfig(
        name: _nameController.text.trim().isEmpty
            ? 'Cricket Tournament'
            : _nameController.text.trim(),
        teams: _teams,
        rules: _rules,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.88,
      padding: EdgeInsets.fromLTRB(
        14,
        8,
        14,
        MediaQuery.paddingOf(context).bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF9F8F2),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(width: 46),
          const SizedBox(height: 10),
          const Text(
            'Tournament Creator',
            style: TextStyle(
              color: RoomColors.plum,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Create league, knockout, round-robin, or group + knockout events.',
            style: TextStyle(
              color: Color(0xFF81758C),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                _TextFieldBlock(
                  label: 'Tournament name',
                  controller: _nameController,
                ),
                const SizedBox(height: 10),
                _TextFieldBlock(
                  label: 'Teams, one per line',
                  controller: _teamsController,
                  minLines: 4,
                  maxLines: 7,
                ),
                const SizedBox(height: 12),
                _TournamentTypePicker(
                  value: _rules.type,
                  onChanged: (type) => setState(
                    () => _rules = _rules.copyWith(type: type),
                  ),
                ),
                const SizedBox(height: 12),
                _RuleGrid(
                  rules: _rules,
                  onChanged: (rules) => setState(() => _rules = rules),
                ),
                const SizedBox(height: 12),
                _RuleSwitches(
                  rules: _rules,
                  onChanged: (rules) => setState(() => _rules = rules),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.emoji_events_rounded),
              label: const Text('Save Tournament Rules'),
            ),
          ),
        ],
      ),
    );
  }
}

class CricketPointsTableSheet extends StatelessWidget {
  const CricketPointsTableSheet({super.key, required this.rows});

  final List<CricketPointsRow> rows;

  @override
  Widget build(BuildContext context) {
    final sorted = [...rows]
      ..sort((a, b) {
        final points = b.points.compareTo(a.points);
        if (points != 0) return points;
        return b.netRunRate.compareTo(a.netRunRate);
      });

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.72,
      padding: EdgeInsets.fromLTRB(
        14,
        8,
        14,
        MediaQuery.paddingOf(context).bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF9F8F2),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(width: 46),
          const SizedBox(height: 10),
          const Text(
            'Points Table',
            style: TextStyle(
              color: RoomColors.plum,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: sorted.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                return _PointsRowCard(rank: index + 1, row: sorted[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ScorerOverlayHeader extends StatelessWidget {
  const _ScorerOverlayHeader({required this.state});

  final CricketMatchState state;

  @override
  Widget build(BuildContext context) {
    final snapshot = state.snapshot;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [Color(0xFF0E5A31), Color(0xFF65FF8F)]),
          ),
          child: const Icon(Icons.sports_cricket_rounded, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scorer Seat • Seat 3',
                style: TextStyle(
                  color: RoomColors.plum.withValues(alpha: 0.78),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${state.battingTeam.shortName} ${snapshot.runs}/${snapshot.wickets} (${snapshot.oversText})',
                style: const TextStyle(
                  color: RoomColors.plum,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CricketMiniBallChip extends StatelessWidget {
  const _CricketMiniBallChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 27),
      height: 27,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF0E5930),
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PremiumScoreButton extends StatelessWidget {
  const _PremiumScoreButton({
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: danger ? RoomColors.coral : Colors.white,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: danger ? Colors.white : RoomColors.plum,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _TextFieldBlock extends StatelessWidget {
  const _TextFieldBlock({
    required this.label,
    required this.controller,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _TournamentTypePicker extends StatelessWidget {
  const _TournamentTypePicker({required this.value, required this.onChanged});

  final CricketTournamentType value;
  final ValueChanged<CricketTournamentType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: CricketTournamentType.values.map((type) {
        final selected = type == value;
        return ChoiceChip(
          selected: selected,
          label: Text(_typeLabel(type)),
          onSelected: (_) => onChanged(type),
        );
      }).toList(),
    );
  }

  String _typeLabel(CricketTournamentType type) {
    return switch (type) {
      CricketTournamentType.knockout => 'Knockout',
      CricketTournamentType.league => 'League',
      CricketTournamentType.roundRobin => 'Round Robin',
      CricketTournamentType.doubleRoundRobin => 'Double RR',
      CricketTournamentType.groupStageKnockout => 'Groups + KO',
    };
  }
}

class _RuleGrid extends StatelessWidget {
  const _RuleGrid({required this.rules, required this.onChanged});

  final CricketTournamentRules rules;
  final ValueChanged<CricketTournamentRules> onChanged;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.65,
      children: [
        _NumberRuleTile(
          label: 'Players/team',
          value: rules.playersPerTeam,
          onChanged: (value) => onChanged(rules.copyWith(playersPerTeam: value)),
        ),
        _NumberRuleTile(
          label: 'Overs',
          value: rules.oversPerInnings,
          onChanged: (value) => onChanged(rules.copyWith(oversPerInnings: value)),
        ),
        _NumberRuleTile(
          label: 'Wickets',
          value: rules.wicketsPerInnings,
          onChanged: (value) => onChanged(rules.copyWith(wicketsPerInnings: value)),
        ),
        _NumberRuleTile(
          label: 'Balls/over',
          value: rules.ballsPerOver,
          onChanged: (value) => onChanged(rules.copyWith(ballsPerOver: value)),
        ),
        _NumberRuleTile(
          label: 'Matches/team',
          value: rules.matchesPerTeam,
          onChanged: (value) => onChanged(rules.copyWith(matchesPerTeam: value)),
        ),
        _NumberRuleTile(
          label: 'Vs each team',
          value: rules.matchesAgainstEachTeam,
          onChanged: (value) =>
              onChanged(rules.copyWith(matchesAgainstEachTeam: value)),
        ),
        _NumberRuleTile(
          label: 'Win pts',
          value: rules.winPoints,
          onChanged: (value) => onChanged(rules.copyWith(winPoints: value)),
        ),
        _NumberRuleTile(
          label: 'Qualifiers',
          value: rules.qualifierCount,
          onChanged: (value) => onChanged(rules.copyWith(qualifierCount: value)),
        ),
      ],
    );
  }
}

class _NumberRuleTile extends StatelessWidget {
  const _NumberRuleTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => onChanged(math.max(1, value - 1)),
            icon: const Icon(Icons.remove_circle_outline_rounded, size: 19),
          ),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w900)),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => onChanged(value + 1),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 19),
          ),
        ],
      ),
    );
  }
}

class _RuleSwitches extends StatelessWidget {
  const _RuleSwitches({required this.rules, required this.onChanged});

  final CricketTournamentRules rules;
  final ValueChanged<CricketTournamentRules> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SwitchTile(
          label: 'Net run rate',
          value: rules.enableNetRunRate,
          onChanged: (value) => onChanged(rules.copyWith(enableNetRunRate: value)),
        ),
        _SwitchTile(
          label: 'Bonus point',
          value: rules.enableBonusPoint,
          onChanged: (value) => onChanged(rules.copyWith(enableBonusPoint: value)),
        ),
        _SwitchTile(
          label: 'Super over',
          value: rules.enableSuperOver,
          onChanged: (value) => onChanged(rules.copyWith(enableSuperOver: value)),
        ),
        _SwitchTile(
          label: 'Last man stands',
          value: rules.enableLastManStands,
          onChanged: (value) =>
              onChanged(rules.copyWith(enableLastManStands: value)),
        ),
        _SwitchTile(
          label: 'Third-place match',
          value: rules.enableThirdPlaceMatch,
          onChanged: (value) =>
              onChanged(rules.copyWith(enableThirdPlaceMatch: value)),
        ),
      ],
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _PointsRowCard extends StatelessWidget {
  const _PointsRowCard({required this.rank, required this.row});

  final int rank;
  final CricketPointsRow row;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RoomColors.softLine),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: rank <= 4 ? RoomColors.gold : RoomColors.plum,
            child: Text(
              '$rank',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.teamName,
                  style: const TextStyle(
                    color: RoomColors.plum,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'P ${row.played} • W ${row.won} • L ${row.lost} • T ${row.tied} • NR ${row.noResult}',
                  style: const TextStyle(
                    color: Color(0xFF81758C),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${row.points} pts',
                style: const TextStyle(
                  color: RoomColors.plum,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'NRR ${row.netRunRate.toStringAsFixed(3)}',
                style: const TextStyle(
                  color: Color(0xFF0E8F54),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
