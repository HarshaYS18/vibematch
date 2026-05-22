import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/ui/vm_motion.dart';
import '../widgets/room_theme.dart';
import 'cricket_room_mode_signal.dart';

const RoomBackgroundTheme cricketFloodlightArenaBackgroundTheme =
    RoomBackgroundTheme(
      id: 'cricket_floodlight_arena',
      name: 'Cricket Floodlight Arena',
      accent: Color(0xFF65FF8F),
      sourceType: RoomBackgroundSourceType.event,
      unlockType: RoomBackgroundUnlockType.free,
      ownershipType: RoomBackgroundOwnershipType.free,
      isDefault: true,
      overlayOpacity: 0.48,
      fallbackColors: [Color(0xFF04130A), Color(0xFF0B3E1F)],
    );

const RoomBackgroundTheme cricketRoyalPitchBackgroundTheme =
    RoomBackgroundTheme(
      id: 'cricket_royal_pitch',
      name: 'Royal Cricket Pitch',
      accent: Color(0xFFFFD36A),
      sourceType: RoomBackgroundSourceType.event,
      unlockType: RoomBackgroundUnlockType.free,
      ownershipType: RoomBackgroundOwnershipType.free,
      isDefault: true,
      overlayOpacity: 0.46,
      fallbackColors: [Color(0xFF09120B), Color(0xFF4C3512)],
    );

const List<RoomBackgroundTheme> cricketModeBackgroundThemes = [
  cricketFloodlightArenaBackgroundTheme,
  cricketRoyalPitchBackgroundTheme,
];

enum CricketMatchStatus { setup, live, inningsBreak, completed }

enum CricketExtraType { wide, noBall, bye, legBye, penalty }

enum CricketWicketType {
  bowled,
  caught,
  lbw,
  runOut,
  stumped,
  hitWicket,
  retired,
}

class CricketPlayer {
  const CricketPlayer({
    required this.id,
    required this.name,
    required this.teamId,
    this.battingOrder = 0,
  });

  final String id;
  final String name;
  final String teamId;
  final int battingOrder;
}

class CricketTeam {
  const CricketTeam({
    required this.id,
    required this.name,
    required this.shortName,
    required this.players,
  });

  final String id;
  final String name;
  final String shortName;
  final List<CricketPlayer> players;
}

class CricketBallEvent {
  const CricketBallEvent({
    required this.sequence,
    required this.innings,
    required this.over,
    required this.ball,
    required this.strikerId,
    required this.nonStrikerId,
    required this.bowlerId,
    required this.runsBat,
    required this.extrasRuns,
    required this.isLegalBall,
    this.extraType,
    this.wicketType,
    this.dismissedPlayerId,
    this.commentary = '',
  });

  final int sequence;
  final int innings;
  final int over;
  final int ball;
  final String strikerId;
  final String nonStrikerId;
  final String bowlerId;
  final int runsBat;
  final int extrasRuns;
  final CricketExtraType? extraType;
  final bool isLegalBall;
  final CricketWicketType? wicketType;
  final String? dismissedPlayerId;
  final String commentary;

  int get totalRuns => runsBat + extrasRuns;
  bool get isWicket => wicketType != null;

  String get chip {
    if (isWicket) return 'W';
    if (extraType == CricketExtraType.wide)
      return extrasRuns > 1 ? 'Wd+$runsBat' : 'Wd';
    if (extraType == CricketExtraType.noBall)
      return runsBat > 0 ? 'Nb+$runsBat' : 'Nb';
    if (extraType == CricketExtraType.bye) return 'B$extrasRuns';
    if (extraType == CricketExtraType.legBye) return 'LB$extrasRuns';
    if (extraType == CricketExtraType.penalty)
      return extrasRuns > 0 ? '+${extrasRuns}P' : '${extrasRuns}P';
    return '$runsBat';
  }
}

class CricketScoreSnapshot {
  const CricketScoreSnapshot({
    required this.runs,
    required this.wickets,
    required this.legalBalls,
    required this.oversText,
    required this.currentRunRate,
    required this.requiredRunRate,
    required this.recentBalls,
  });

  final int runs;
  final int wickets;
  final int legalBalls;
  final String oversText;
  final double currentRunRate;
  final double? requiredRunRate;
  final List<String> recentBalls;
}

class CricketMatchState {
  const CricketMatchState({
    required this.roomId,
    required this.roomName,
    required this.teamA,
    required this.teamB,
    required this.oversLimit,
    required this.ballsPerOver,
    required this.totalWickets,
    required this.status,
    required this.innings,
    required this.battingTeamId,
    required this.bowlingTeamId,
    required this.strikerId,
    required this.nonStrikerId,
    required this.bowlerId,
    required this.nextBatterIndex,
    required this.events,
    this.targetRuns,
  });

  final String roomId;
  final String roomName;
  final CricketTeam teamA;
  final CricketTeam teamB;
  final int oversLimit;
  final int ballsPerOver;
  final int totalWickets;
  final CricketMatchStatus status;
  final int innings;
  final String battingTeamId;
  final String bowlingTeamId;
  final String strikerId;
  final String nonStrikerId;
  final String bowlerId;
  final int nextBatterIndex;
  final int? targetRuns;
  final List<CricketBallEvent> events;

  CricketTeam get battingTeam => battingTeamId == teamA.id ? teamA : teamB;
  CricketTeam get bowlingTeam => bowlingTeamId == teamA.id ? teamA : teamB;
  List<CricketBallEvent> get inningsEvents =>
      events.where((e) => e.innings == innings).toList(growable: false);

  CricketPlayer playerById(String id) {
    return [...teamA.players, ...teamB.players].firstWhere(
      (player) => player.id == id,
      orElse: () =>
          CricketPlayer(id: id, name: 'Player', teamId: battingTeamId),
    );
  }

  CricketScoreSnapshot get snapshot => CricketScoringEngine.snapshot(this);

  CricketMatchState copyWith({
    CricketMatchStatus? status,
    int? innings,
    String? battingTeamId,
    String? bowlingTeamId,
    String? strikerId,
    String? nonStrikerId,
    String? bowlerId,
    int? nextBatterIndex,
    int? targetRuns,
    List<CricketBallEvent>? events,
  }) {
    return CricketMatchState(
      roomId: roomId,
      roomName: roomName,
      teamA: teamA,
      teamB: teamB,
      oversLimit: oversLimit,
      ballsPerOver: ballsPerOver,
      totalWickets: totalWickets,
      status: status ?? this.status,
      innings: innings ?? this.innings,
      battingTeamId: battingTeamId ?? this.battingTeamId,
      bowlingTeamId: bowlingTeamId ?? this.bowlingTeamId,
      strikerId: strikerId ?? this.strikerId,
      nonStrikerId: nonStrikerId ?? this.nonStrikerId,
      bowlerId: bowlerId ?? this.bowlerId,
      nextBatterIndex: nextBatterIndex ?? this.nextBatterIndex,
      targetRuns: targetRuns ?? this.targetRuns,
      events: events ?? this.events,
    );
  }
}

class CricketScoringEngine {
  const CricketScoringEngine._();

  static CricketMatchState demo({
    required String roomId,
    required String roomName,
  }) {
    final teamAPlayers = List<CricketPlayer>.generate(
      11,
      (index) => CricketPlayer(
        id: 'a_${index + 1}',
        name: [
          'Arjun',
          'Dev',
          'Kiran',
          'Manoj',
          'Sai',
          'Rohit',
          'Varun',
          'Nikhil',
          'Yash',
          'Ravi',
          'Ajay',
        ][index],
        teamId: 'team_a',
        battingOrder: index + 1,
      ),
    );
    final teamBPlayers = List<CricketPlayer>.generate(
      11,
      (index) => CricketPlayer(
        id: 'b_${index + 1}',
        name: [
          'Ravi',
          'Bala',
          'Surya',
          'Mahesh',
          'Vikram',
          'Charan',
          'Teja',
          'Pavan',
          'Abhi',
          'Karthik',
          'Venu',
        ][index],
        teamId: 'team_b',
        battingOrder: index + 1,
      ),
    );

    return CricketMatchState(
      roomId: roomId,
      roomName: roomName,
      teamA: CricketTeam(
        id: 'team_a',
        name: 'Vibe Strikers',
        shortName: 'VBS',
        players: teamAPlayers,
      ),
      teamB: CricketTeam(
        id: 'team_b',
        name: 'Royal Hitters',
        shortName: 'RHT',
        players: teamBPlayers,
      ),
      oversLimit: 5,
      ballsPerOver: 6,
      totalWickets: 10,
      status: CricketMatchStatus.setup,
      innings: 1,
      battingTeamId: 'team_a',
      bowlingTeamId: 'team_b',
      strikerId: teamAPlayers[0].id,
      nonStrikerId: teamAPlayers[1].id,
      bowlerId: teamBPlayers[0].id,
      nextBatterIndex: 2,
      events: const [],
    );
  }

  static CricketMatchState fromQuickSetup(CricketQuickMatchSetup setup) {
    CricketTeam convertTeam(CricketQuickMatchTeamSetup team) {
      final shortName = team.name
          .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
          .toUpperCase()
          .padRight(3, 'X')
          .substring(0, 3);
      return CricketTeam(
        id: team.id,
        name: team.name,
        shortName: shortName,
        players: List<CricketPlayer>.generate(
          team.players.length,
          (index) => CricketPlayer(
            id: team.players[index].id,
            name: team.players[index].name,
            teamId: team.id,
            battingOrder: index + 1,
          ),
        ),
      );
    }

    final teamA = convertTeam(setup.teamA);
    final teamB = convertTeam(setup.teamB);

    return CricketMatchState(
      roomId: setup.roomId,
      roomName: setup.roomName,
      teamA: teamA,
      teamB: teamB,
      oversLimit: setup.overs,
      ballsPerOver: 6,
      totalWickets: setup.wickets,
      status: CricketMatchStatus.live,
      innings: 1,
      battingTeamId: setup.battingTeamId,
      bowlingTeamId: setup.bowlingTeamId,
      strikerId: setup.strikerId,
      nonStrikerId: setup.nonStrikerId,
      bowlerId: setup.bowlerId,
      nextBatterIndex: 2,
      events: const [],
    );
  }

  static CricketScoreSnapshot snapshot(CricketMatchState state) {
    final inningsEvents = state.inningsEvents;
    final runs = inningsEvents.fold<int>(
      0,
      (sum, event) => sum + event.totalRuns,
    );
    final wickets = inningsEvents.where((event) => event.isWicket).length;
    final legalBalls = inningsEvents.where((event) => event.isLegalBall).length;
    final currentRunRate = legalBalls == 0
        ? 0.0
        : runs / (legalBalls / state.ballsPerOver);
    final ballsLeft = math.max(
      0,
      (state.oversLimit * state.ballsPerOver) - legalBalls,
    );
    final required = state.targetRuns == null || ballsLeft == 0
        ? null
        : math.max(0, state.targetRuns! - runs) /
              (ballsLeft / state.ballsPerOver);

    return CricketScoreSnapshot(
      runs: runs,
      wickets: wickets,
      legalBalls: legalBalls,
      oversText:
          '${legalBalls ~/ state.ballsPerOver}.${legalBalls % state.ballsPerOver}',
      currentRunRate: currentRunRate,
      requiredRunRate: required,
      recentBalls: inningsEvents.reversed
          .take(6)
          .map((event) => event.chip)
          .toList()
          .reversed
          .toList(),
    );
  }

  static CricketMatchState addRuns(CricketMatchState state, int runs) {
    return _appendBall(state, runsBat: runs, extrasRuns: 0, isLegalBall: true);
  }

  static CricketMatchState addExtra(
    CricketMatchState state,
    CricketExtraType type,
    int runs,
  ) {
    final isLegal =
        type == CricketExtraType.bye ||
        type == CricketExtraType.legBye ||
        type == CricketExtraType.penalty;
    final extras =
        type == CricketExtraType.wide || type == CricketExtraType.noBall
        ? math.max(1, runs)
        : runs;
    return _appendBall(
      state,
      runsBat: 0,
      extrasRuns: extras,
      extraType: type,
      isLegalBall: isLegal,
    );
  }

  static CricketMatchState addNoBallRuns(CricketMatchState state, int batRuns) {
    return _appendBall(
      state,
      runsBat: math.max(0, batRuns),
      extrasRuns: 1,
      extraType: CricketExtraType.noBall,
      isLegalBall: false,
    );
  }

  static CricketMatchState addPenalty(CricketMatchState state, int runs) {
    final safeRuns = runs.clamp(-1, 1);
    if (safeRuns == 0) return state;

    return _appendBall(
      state,
      runsBat: 0,
      extrasRuns: safeRuns,
      extraType: CricketExtraType.penalty,
      isLegalBall: false,
    );
  }

  static CricketMatchState addWicket(
    CricketMatchState state,
    CricketWicketType type,
  ) {
    return _appendBall(
      state,
      runsBat: 0,
      extrasRuns: 0,
      isLegalBall: type != CricketWicketType.runOut,
      wicketType: type,
      dismissedPlayerId: state.strikerId,
    );
  }

  static CricketMatchState undoLastBall(CricketMatchState state) {
    if (state.events.isEmpty) return state;
    final nextEvents = List<CricketBallEvent>.from(state.events)..removeLast();
    return _replay(state.copyWith(events: const []), nextEvents);
  }

  static CricketMatchState endInnings(CricketMatchState state) {
    if (state.innings == 2)
      return state.copyWith(status: CricketMatchStatus.completed);
    final target = snapshot(state).runs + 1;
    return state.copyWith(
      status: CricketMatchStatus.inningsBreak,
      targetRuns: target,
    );
  }

  static CricketMatchState startSecondInnings(CricketMatchState state) {
    final batting = state.teamB;
    final bowling = state.teamA;
    return state.copyWith(
      status: CricketMatchStatus.live,
      innings: 2,
      battingTeamId: batting.id,
      bowlingTeamId: bowling.id,
      strikerId: batting.players[0].id,
      nonStrikerId: batting.players[1].id,
      bowlerId: bowling.players[0].id,
      nextBatterIndex: 2,
    );
  }

  static CricketMatchState _appendBall(
    CricketMatchState state, {
    required int runsBat,
    required int extrasRuns,
    required bool isLegalBall,
    CricketExtraType? extraType,
    CricketWicketType? wicketType,
    String? dismissedPlayerId,
  }) {
    if (state.status != CricketMatchStatus.live) return state;
    final legalBalls = state.inningsEvents
        .where((event) => event.isLegalBall)
        .length;
    final nextLegalBall = legalBalls + (isLegalBall ? 1 : 0);
    final event = CricketBallEvent(
      sequence: state.events.length + 1,
      innings: state.innings,
      over: legalBalls ~/ state.ballsPerOver,
      ball: isLegalBall
          ? ((nextLegalBall - 1) % state.ballsPerOver) + 1
          : (legalBalls % state.ballsPerOver) + 1,
      strikerId: state.strikerId,
      nonStrikerId: state.nonStrikerId,
      bowlerId: state.bowlerId,
      runsBat: runsBat,
      extrasRuns: extrasRuns,
      extraType: extraType,
      isLegalBall: isLegalBall,
      wicketType: wicketType,
      dismissedPlayerId: dismissedPlayerId,
      commentary: _commentary(
        state,
        runsBat,
        extrasRuns,
        extraType,
        wicketType,
      ),
    );

    var striker = state.strikerId;
    var nonStriker = state.nonStrikerId;
    var nextBatterIndex = state.nextBatterIndex;

    if (wicketType != null &&
        nextBatterIndex < state.battingTeam.players.length) {
      striker = state.battingTeam.players[nextBatterIndex].id;
      nextBatterIndex += 1;
    } else if ((runsBat +
            (extraType == CricketExtraType.bye ||
                    extraType == CricketExtraType.legBye
                ? extrasRuns
                : 0))
        .isOdd) {
      final temp = striker;
      striker = nonStriker;
      nonStriker = temp;
    }

    if (isLegalBall && nextLegalBall % state.ballsPerOver == 0) {
      final temp = striker;
      striker = nonStriker;
      nonStriker = temp;
    }

    var next = state.copyWith(
      events: [...state.events, event],
      strikerId: striker,
      nonStrikerId: nonStriker,
      nextBatterIndex: nextBatterIndex,
    );

    final snap = snapshot(next);
    final allOut = snap.wickets >= state.totalWickets;
    final oversDone = snap.legalBalls >= state.oversLimit * state.ballsPerOver;
    final targetReached =
        state.targetRuns != null && snap.runs >= state.targetRuns!;
    if (allOut || oversDone || targetReached) {
      if (next.innings == 1) {
        return endInnings(next);
      }
      return next.copyWith(status: CricketMatchStatus.completed);
    }
    return next;
  }

  static CricketMatchState _replay(
    CricketMatchState seed,
    List<CricketBallEvent> events,
  ) {
    var next = seed.copyWith(status: CricketMatchStatus.live);
    for (final event in events) {
      if (event.isWicket) {
        next = addWicket(next, event.wicketType!);
      } else if (event.extraType != null) {
        next = addExtra(next, event.extraType!, event.extrasRuns);
      } else {
        next = addRuns(next, event.runsBat);
      }
    }
    return next;
  }

  static String _commentary(
    CricketMatchState state,
    int runsBat,
    int extrasRuns,
    CricketExtraType? extraType,
    CricketWicketType? wicketType,
  ) {
    final striker = state.playerById(state.strikerId).name;
    final bowler = state.playerById(state.bowlerId).name;
    if (wicketType != null)
      return '$bowler to $striker, OUT! ${_wicketLabel(wicketType)}.';
    if (extraType != null)
      return '$bowler to $striker, ${_extraLabel(extraType)} $extrasRuns.';
    if (runsBat == 4) return '$bowler to $striker, FOUR!';
    if (runsBat == 6) return '$bowler to $striker, SIX!';
    if (runsBat == 0) return '$bowler to $striker, dot ball.';
    return '$bowler to $striker, $runsBat run${runsBat == 1 ? '' : 's'}.';
  }

  static String _extraLabel(CricketExtraType type) => switch (type) {
    CricketExtraType.wide => 'wide',
    CricketExtraType.noBall => 'no-ball',
    CricketExtraType.bye => 'bye',
    CricketExtraType.legBye => 'leg-bye',
    CricketExtraType.penalty => 'penalty',
  };

  static String _wicketLabel(CricketWicketType type) => switch (type) {
    CricketWicketType.bowled => 'Bowled',
    CricketWicketType.caught => 'Caught',
    CricketWicketType.lbw => 'LBW',
    CricketWicketType.runOut => 'Run out',
    CricketWicketType.stumped => 'Stumped',
    CricketWicketType.hitWicket => 'Hit wicket',
    CricketWicketType.retired => 'Retired',
  };
}

class CricketModeController extends ChangeNotifier {
  CricketModeController({required String roomId, required String roomName})
    : _roomId = roomId,
      _roomName = roomName,
      _state = CricketScoringEngine.demo(roomId: roomId, roomName: roomName);

  final String _roomId;
  final String _roomName;

  CricketMatchState _state;
  CricketMatchState get state => _state;

  void resetDemo() {
    _state = CricketScoringEngine.demo(roomId: _roomId, roomName: _roomName);
    notifyListeners();
  }

  void loadQuickMatch(CricketQuickMatchSetup setup) {
    _state = CricketScoringEngine.fromQuickSetup(setup);
    notifyListeners();
  }

  bool get isActive =>
      _state.status == CricketMatchStatus.live ||
      _state.status == CricketMatchStatus.inningsBreak;

  void startMatch() => _set(_state.copyWith(status: CricketMatchStatus.live));
  void addRuns(int runs) => _set(CricketScoringEngine.addRuns(_state, runs));
  void addExtra(CricketExtraType type, int runs) =>
      _set(CricketScoringEngine.addExtra(_state, type, runs));
  void addNoBallRuns(int runs) =>
      _set(CricketScoringEngine.addNoBallRuns(_state, runs));
  void addPenalty(int runs) =>
      _set(CricketScoringEngine.addPenalty(_state, runs));
  void addWicket(CricketWicketType type) =>
      _set(CricketScoringEngine.addWicket(_state, type));
  void undo() => _set(CricketScoringEngine.undoLastBall(_state));
  void endInnings() => _set(CricketScoringEngine.endInnings(_state));
  void startSecondInnings() =>
      _set(CricketScoringEngine.startSecondInnings(_state));
  void complete() =>
      _set(_state.copyWith(status: CricketMatchStatus.completed));

  void setStrikerPlayer(String playerId) {
    _set(_state.copyWith(strikerId: playerId));
  }

  void setNonStrikerPlayer(String playerId) {
    _set(_state.copyWith(nonStrikerId: playerId));
  }

  void setBowlerPlayer(String playerId) {
    _set(_state.copyWith(bowlerId: playerId));
  }

  void _set(CricketMatchState value) {
    _state = value;
    notifyListeners();
  }
}

class CricketModeModule {
  const CricketModeModule._();

  static Future<void> open({
    required BuildContext context,
    required String roomId,
    required String roomName,
    required bool canManage,
    required RoomBackgroundTheme previousBackground,
    required ValueChanged<RoomBackgroundTheme> onBackgroundChanged,
    ValueChanged<String>? onSystemMessage,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: VmMotion.sheetAnimationStyle,
      builder: (_) => CricketModeSheet(
        roomId: roomId,
        roomName: roomName,
        canManage: canManage,
        previousBackground: previousBackground,
        onBackgroundChanged: onBackgroundChanged,
        onSystemMessage: onSystemMessage,
      ),
    );
  }
}

class CricketModeSheet extends StatefulWidget {
  const CricketModeSheet({
    super.key,
    required this.roomId,
    required this.roomName,
    required this.canManage,
    required this.previousBackground,
    required this.onBackgroundChanged,
    this.onSystemMessage,
  });

  final String roomId;
  final String roomName;
  final bool canManage;
  final RoomBackgroundTheme previousBackground;
  final ValueChanged<RoomBackgroundTheme> onBackgroundChanged;
  final ValueChanged<String>? onSystemMessage;

  @override
  State<CricketModeSheet> createState() => _CricketModeSheetState();
}

class _CricketModeSheetState extends State<CricketModeSheet> {
  late final CricketModeController _controller;
  RoomBackgroundTheme _selectedCricketBackground =
      cricketFloodlightArenaBackgroundTheme;

  @override
  void initState() {
    super.initState();
    _controller = CricketModeController(
      roomId: widget.roomId,
      roomName: widget.roomName,
    )..addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  void _startMode() {
    if (!widget.canManage) {
      RoomToast.show(context, 'Only room owner/admin can start Cricket Mode');
      return;
    }
    widget.onBackgroundChanged(_selectedCricketBackground);
    CricketRoomModeSignal.activate(widget.roomId);
    _controller.startMatch();
    widget.onSystemMessage?.call(
      'Cricket Mode started. Room background switched to ${_selectedCricketBackground.name}.',
    );
  }

  void _endMode() {
    _controller.complete();
    CricketRoomModeSignal.deactivate(widget.roomId);
    widget.onBackgroundChanged(widget.previousBackground);
    widget.onSystemMessage?.call(
      'Cricket Mode ended. Room background restored.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final snapshot = state.snapshot;
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.86,
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
          _Header(
            status: state.status,
            canManage: widget.canManage,
            onEnd: _endMode,
          ),
          const SizedBox(height: 12),
          _ScorePanel(state: state, snapshot: snapshot),
          const SizedBox(height: 10),
          if (state.status == CricketMatchStatus.setup)
            _SetupPanel(
              selected: _selectedCricketBackground,
              onSelected: (theme) =>
                  setState(() => _selectedCricketBackground = theme),
              onStart: _startMode,
            ),
          if (state.status == CricketMatchStatus.live)
            _ScorerKeypad(controller: _controller, canManage: widget.canManage),
          if (state.status == CricketMatchStatus.inningsBreak)
            _InningsBreakPanel(
              state: state,
              onStartSecondInnings: _controller.startSecondInnings,
              onComplete: _controller.complete,
            ),
          if (state.status == CricketMatchStatus.completed)
            _CompletedPanel(state: state),
          const SizedBox(height: 10),
          Expanded(
            child: _CommentaryList(
              events: state.events.reversed.toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.status,
    required this.canManage,
    required this.onEnd,
  });

  final CricketMatchStatus status;
  final bool canManage;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cricket Mode',
                style: TextStyle(
                  color: RoomColors.plum,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Ball-by-ball scorer • live room mode • backend-ready events',
                style: TextStyle(
                  color: Color(0xFF7C7186),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        if (status == CricketMatchStatus.live ||
            status == CricketMatchStatus.inningsBreak)
          TextButton.icon(
            onPressed: canManage ? onEnd : null,
            icon: const Icon(Icons.stop_circle_rounded, size: 17),
            label: const Text('End'),
          ),
      ],
    );
  }
}

class _ScorePanel extends StatelessWidget {
  const _ScorePanel({required this.state, required this.snapshot});

  final CricketMatchState state;
  final CricketScoreSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final striker = state.playerById(state.strikerId).name;
    final nonStriker = state.playerById(state.nonStrikerId).name;
    final bowler = state.playerById(state.bowlerId).name;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF062611), Color(0xFF0E5930)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${state.battingTeam.shortName} ${snapshot.runs}/${snapshot.wickets} (${snapshot.oversText})',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            state.targetRuns == null
                ? '${state.battingTeam.name} batting'
                : 'Target ${state.targetRuns} • Need ${math.max(0, state.targetRuns! - snapshot.runs)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _InfoChip(label: '$striker *'),
              _InfoChip(label: nonStriker),
              _InfoChip(label: 'Bowler $bowler'),
              _InfoChip(
                label: 'CRR ${snapshot.currentRunRate.toStringAsFixed(2)}',
              ),
              if (snapshot.requiredRunRate != null)
                _InfoChip(
                  label: 'RRR ${snapshot.requiredRunRate!.toStringAsFixed(2)}',
                ),
            ],
          ),
          if (snapshot.recentBalls.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: snapshot.recentBalls
                  .map((ball) => _BallChip(ball))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _BallChip extends StatelessWidget {
  const _BallChip(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    width: 30,
    height: 30,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFF0E5930),
        fontSize: 10.5,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _SetupPanel extends StatelessWidget {
  const _SetupPanel({
    required this.selected,
    required this.onSelected,
    required this.onStart,
  });
  final RoomBackgroundTheme selected;
  final ValueChanged<RoomBackgroundTheme> onSelected;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cricket backgrounds',
          style: TextStyle(
            color: RoomColors.plum,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: cricketModeBackgroundThemes.map((theme) {
            final active = selected.id == theme.id;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => onSelected(theme),
                  child: Container(
                    height: 72,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: theme.fallbackColors),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: active ? theme.accent : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        theme.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.sports_cricket_rounded),
            label: const Text('Start Cricket Mode'),
          ),
        ),
      ],
    );
  }
}

class _ScorerKeypad extends StatelessWidget {
  const _ScorerKeypad({required this.controller, required this.canManage});
  final CricketModeController controller;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !canManage,
      child: Opacity(
        opacity: canManage ? 1 : 0.45,
        child: Column(
          children: [
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.55,
              children:
                  [0, 1, 2, 3, 4, 5, 6]
                      .map(
                        (run) => _ScoreButton(
                          label: '$run',
                          onTap: () => controller.addRuns(run),
                        ),
                      )
                      .toList()
                    ..addAll([
                      _ScoreButton(
                        label: 'Wd',
                        onTap: () =>
                            controller.addExtra(CricketExtraType.wide, 1),
                      ),
                      _ScoreButton(
                        label: 'Nb',
                        onTap: () =>
                            controller.addExtra(CricketExtraType.noBall, 1),
                      ),
                      _ScoreButton(
                        label: 'Bye',
                        onTap: () =>
                            controller.addExtra(CricketExtraType.bye, 1),
                      ),
                      _ScoreButton(
                        label: 'LB',
                        onTap: () =>
                            controller.addExtra(CricketExtraType.legBye, 1),
                      ),
                      _ScoreButton(
                        label: 'Wicket',
                        danger: true,
                        onTap: () =>
                            controller.addWicket(CricketWicketType.bowled),
                      ),
                    ]),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: controller.undo,
                    icon: const Icon(Icons.undo_rounded),
                    label: const Text('Undo'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: controller.endInnings,
                    icon: const Icon(Icons.flag_rounded),
                    label: const Text('End innings'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreButton extends StatelessWidget {
  const _ScoreButton({
    required this.label,
    required this.onTap,
    this.danger = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) => Material(
    color: danger ? RoomColors.coral : Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
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

class _InningsBreakPanel extends StatelessWidget {
  const _InningsBreakPanel({
    required this.state,
    required this.onStartSecondInnings,
    required this.onComplete,
  });
  final CricketMatchState state;
  final VoidCallback onStartSecondInnings;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: FilledButton(
          onPressed: state.innings == 1 ? onStartSecondInnings : onComplete,
          child: Text(
            state.innings == 1 ? 'Start 2nd Innings' : 'Complete Match',
          ),
        ),
      ),
    ],
  );
}

class _CompletedPanel extends StatelessWidget {
  const _CompletedPanel({required this.state});
  final CricketMatchState state;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: RoomColors.gold.withValues(alpha: 0.20),
      borderRadius: BorderRadius.circular(18),
    ),
    child: const Text(
      'Match completed. Scorecard, player stats, and backend sync hooks are ready for connection.',
      style: TextStyle(color: RoomColors.plum, fontWeight: FontWeight.w900),
    ),
  );
}

class _CommentaryList extends StatelessWidget {
  const _CommentaryList({required this.events});
  final List<CricketBallEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Center(
        child: Text(
          'No balls yet. Start scoring to generate ball-by-ball commentary.',
          style: TextStyle(
            color: Color(0xFF81758C),
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: events.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final event = events[index];
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: _BallChip(event.chip),
          title: Text(
            event.commentary,
            style: const TextStyle(
              color: RoomColors.plum,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            '${event.over}.${event.ball} • Innings ${event.innings}',
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
          ),
        );
      },
    );
  }
}
