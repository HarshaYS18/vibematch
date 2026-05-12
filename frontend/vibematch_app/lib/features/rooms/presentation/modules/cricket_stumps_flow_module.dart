import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/cricket_stumps_flow_repository.dart';
import '../widgets/room_theme.dart';
import 'cricket_room_mode_signal.dart';

const RoomBackgroundTheme cricketStumpsPitchBackgroundTheme = RoomBackgroundTheme(
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

class CricketStumpsFlowModule {
  CricketStumpsFlowModule._();

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
      builder: (_) => _StumpsFlowSheet(
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

class StumpsTournament {
  const StumpsTournament({
    required this.id,
    required this.name,
    required this.teams,
    required this.overs,
    required this.wickets,
    required this.playersPerTeam,
    required this.matchesPerTeam,
    required this.matchesVsEachTeam,
    required this.allowSamePlayerAcrossTeams,
    required this.fixtures,
    this.backendId,
  });

  final String id;
  final int? backendId;
  final String name;
  final List<StumpsTeam> teams;
  final int overs;
  final int wickets;
  final int playersPerTeam;
  final int matchesPerTeam;
  final int matchesVsEachTeam;
  final bool allowSamePlayerAcrossTeams;
  final List<StumpsFixture> fixtures;

  factory StumpsTournament.fromApi(Map<String, dynamic> json) {
    final teams = (json['teams'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(StumpsTeam.fromJson)
        .toList();
    final teamsById = {for (final team in teams) team.id: team};
    final fixtures = (json['fixtures'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((fixture) => StumpsFixture.fromJson(fixture, teamsById))
        .toList();
    final backendId = _asInt(json['id']);
    return StumpsTournament(
      id: backendId?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      backendId: backendId,
      name: json['name']?.toString() ?? 'Cricket Tournament',
      teams: teams,
      overs: _asInt(json['overs_per_innings']) ?? _asInt(json['overs']) ?? 5,
      wickets: _asInt(json['wickets_per_side']) ?? _asInt(json['wickets']) ?? 4,
      playersPerTeam: _asInt(json['players_per_team']) ?? 5,
      matchesPerTeam: _asInt(json['matches_per_team']) ?? 1,
      matchesVsEachTeam: _asInt(json['matches_vs_each_team']) ?? 1,
      allowSamePlayerAcrossTeams: json['allow_same_player_across_teams'] == true,
      fixtures: fixtures,
    );
  }
}

class StumpsTeam {
  const StumpsTeam({required this.id, required this.name, required this.players});
  final String id;
  final String name;
  final List<StumpsPlayer> players;

  factory StumpsTeam.fromJson(Map<String, dynamic> json) {
    final fallbackName = json['name']?.toString() ?? 'Team';
    return StumpsTeam(
      id: json['id']?.toString() ?? fallbackName.toLowerCase().replaceAll(' ', '_'),
      name: fallbackName,
      players: (json['players'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(StumpsPlayer.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'players': players.map((player) => player.toJson()).toList(),
      };
}

class StumpsPlayer {
  const StumpsPlayer({required this.id, required this.name});
  final String id;
  final String name;

  factory StumpsPlayer.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? json['public_user_id']?.toString() ?? '';
    return StumpsPlayer(
      id: id.isEmpty ? DateTime.now().microsecondsSinceEpoch.toString() : id,
      name: json['name']?.toString() ?? json['display_name']?.toString() ?? 'Player $id',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class StumpsFixture {
  const StumpsFixture({required this.id, required this.teamA, required this.teamB, required this.round});
  final String id;
  final StumpsTeam teamA;
  final StumpsTeam teamB;
  final int round;

  factory StumpsFixture.fromJson(Map<String, dynamic> json, Map<String, StumpsTeam> teamsById) {
    final teamAJson = json['team_a'];
    final teamBJson = json['team_b'];
    final teamAId = json['team_a_id']?.toString();
    final teamBId = json['team_b_id']?.toString();
    final teamA = teamAJson is Map<String, dynamic>
        ? StumpsTeam.fromJson(teamAJson)
        : teamsById[teamAId] ?? const StumpsTeam(id: 'team_a', name: 'Team A', players: []);
    final teamB = teamBJson is Map<String, dynamic>
        ? StumpsTeam.fromJson(teamBJson)
        : teamsById[teamBId] ?? const StumpsTeam(id: 'team_b', name: 'Team B', players: []);
    return StumpsFixture(
      id: json['id']?.toString() ?? 'fx_${DateTime.now().microsecondsSinceEpoch}',
      teamA: teamA,
      teamB: teamB,
      round: _asInt(json['round']) ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'round': round,
        'team_a_id': teamA.id,
        'team_b_id': teamB.id,
        'team_a': teamA.toJson(),
        'team_b': teamB.toJson(),
      };
}

enum _FlowStep { home, create, matches, quick, toss, lineups }
enum _TossDecision { bat, ball }

class _StumpsFlowSheet extends StatefulWidget {
  const _StumpsFlowSheet({
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
  State<_StumpsFlowSheet> createState() => _StumpsFlowSheetState();
}

class _StumpsFlowSheetState extends State<_StumpsFlowSheet> {
  final CricketStumpsFlowRepository _repository = const CricketStumpsFlowRepository();

  _FlowStep _step = _FlowStep.home;
  StumpsTournament? _selectedTournament;
  StumpsFixture? _selectedFixture;
  StumpsTeam? _tossWinner;
  _TossDecision? _decision;
  StumpsPlayer? _striker;
  StumpsPlayer? _nonStriker;
  StumpsPlayer? _bowler;
  int? _activeMatchId;
  bool _loading = true;
  bool _saving = false;
  String? _errorText;
  List<StumpsTournament> _tournaments = <StumpsTournament>[];

  final _name = TextEditingController(text: 'Vibe Premier Cup');
  final _teamCount = TextEditingController(text: '4');
  final _playersPerTeam = TextEditingController(text: '5');
  final _overs = TextEditingController(text: '5');
  final _wickets = TextEditingController(text: '4');
  final _matchesPerTeam = TextEditingController(text: '3');
  final _matchesVsEach = TextEditingController(text: '1');
  final _teamName = TextEditingController();
  final _playerId = TextEditingController();
  final _quickA = TextEditingController(text: 'Vibe Strikers');
  final _quickB = TextEditingController(text: 'Royal Hitters');

  bool _allowDuplicatePlayers = false;
  final List<String> _teamNames = <String>[];
  final Map<String, List<StumpsPlayer>> _playersByTeam = <String, List<StumpsPlayer>>{};

  int get _teamTarget => math.max(2, int.tryParse(_teamCount.text) ?? 2);
  int get _playerTarget => math.max(2, int.tryParse(_playersPerTeam.text) ?? 5);
  int get _oversValue => math.max(1, int.tryParse(_overs.text) ?? 5);
  int get _wicketsValue => math.max(1, int.tryParse(_wickets.text) ?? 4);
  int get _matchesPerTeamValue => math.max(1, int.tryParse(_matchesPerTeam.text) ?? 1);
  int get _matchesVsEachValue => math.max(1, int.tryParse(_matchesVsEach.text) ?? 1);

  @override
  void initState() {
    super.initState();
    _loadTournaments();
  }

  @override
  void dispose() {
    _name.dispose();
    _teamCount.dispose();
    _playersPerTeam.dispose();
    _overs.dispose();
    _wickets.dispose();
    _matchesPerTeam.dispose();
    _matchesVsEach.dispose();
    _teamName.dispose();
    _playerId.dispose();
    _quickA.dispose();
    _quickB.dispose();
    super.dispose();
  }

  Future<void> _loadTournaments() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      final rows = await _repository.loadTournaments(widget.roomId);
      if (!mounted) return;
      setState(() {
        _tournaments = rows.map(StumpsTournament.fromApi).toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorText = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.9,
      padding: EdgeInsets.fromLTRB(14, 8, 14, MediaQuery.paddingOf(context).bottom + 12),
      decoration: const BoxDecoration(color: Color(0xFFF9F8F2), borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: Column(children: [
        const SheetHandle(width: 48),
        const SizedBox(height: 10),
        _Header(title: _title, subtitle: _subtitle, canBack: _step != _FlowStep.home, onBack: () => setState(() => _step = _FlowStep.home)),
        const SizedBox(height: 12),
        Expanded(child: _body()),
      ]),
    );
  }

  String get _title => switch (_step) {
        _FlowStep.home => 'Cricket Mode',
        _FlowStep.create => 'Create Tournament',
        _FlowStep.matches => _selectedTournament?.name ?? 'Matches',
        _FlowStep.quick => 'Quick Match',
        _FlowStep.toss => 'Toss',
        _FlowStep.lineups => 'Opening Lineup',
      };

  String get _subtitle => switch (_step) {
        _FlowStep.home => _tournaments.isEmpty ? 'Create tournament or start quick match.' : 'Select tournament, create new, or quick match.',
        _FlowStep.create => 'Team count → names → players by ID → rules → randomized fixtures.',
        _FlowStep.matches => 'Choose a fixture and start match.',
        _FlowStep.quick => 'Fast setup without saving tournament.',
        _FlowStep.toss => 'Choose toss winner and decision.',
        _FlowStep.lineups => 'Pick two opening batters and opening bowler.',
      };

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return switch (_step) {
      _FlowStep.home => _home(),
      _FlowStep.create => _create(),
      _FlowStep.matches => _matches(),
      _FlowStep.quick => _quick(),
      _FlowStep.toss => _toss(),
      _FlowStep.lineups => _lineups(),
    };
  }

  Widget _home() {
    return ListView(physics: const BouncingScrollPhysics(), children: [
      if (_errorText != null) _ErrorCard(message: _errorText!, onRetry: _loadTournaments),
      for (final tournament in _tournaments)
        _Tile(
          icon: Icons.emoji_events_rounded,
          title: tournament.name,
          subtitle: '${tournament.teams.length} teams • ${tournament.fixtures.length} matches',
          onTap: () => setState(() { _selectedTournament = tournament; _step = _FlowStep.matches; }),
          trailing: widget.canManage
              ? IconButton(
                  tooltip: 'Delete tournament',
                  icon: const Icon(Icons.delete_outline_rounded, color: RoomColors.coral),
                  onPressed: () => _deleteTournament(tournament),
                )
              : null,
        ),
      _Tile(icon: Icons.add_circle_rounded, title: 'Create New Tournament', subtitle: 'Full guided tournament setup.', onTap: widget.canManage ? () => setState(() => _step = _FlowStep.create) : null),
      _Tile(icon: Icons.flash_on_rounded, title: 'Quick Match', subtitle: 'Two teams, toss, lineup, start scoring.', onTap: widget.canManage ? () => setState(() => _step = _FlowStep.quick) : null),
    ]);
  }

  Widget _create() {
    final needsTeams = _teamNames.length < _teamTarget;
    final nextTeamForPlayer = needsTeams ? null : _teamNames.where((team) => (_playersByTeam[team]?.length ?? 0) < _playerTarget).firstOrNull;
    return ListView(physics: const BouncingScrollPhysics(), children: [
      _Input(label: 'Tournament name', controller: _name),
      Row(children: [Expanded(child: _Input(label: 'No. of teams', controller: _teamCount, number: true)), const SizedBox(width: 8), Expanded(child: _Input(label: 'Players/team', controller: _playersPerTeam, number: true))]),
      Row(children: [Expanded(child: _Input(label: 'Overs', controller: _overs, number: true)), const SizedBox(width: 8), Expanded(child: _Input(label: 'Wickets/side', controller: _wickets, number: true))]),
      Row(children: [Expanded(child: _Input(label: 'Matches/team', controller: _matchesPerTeam, number: true)), const SizedBox(width: 8), Expanded(child: _Input(label: 'Vs each team', controller: _matchesVsEach, number: true))]),
      SwitchListTile.adaptive(value: _allowDuplicatePlayers, onChanged: (value) => setState(() => _allowDuplicatePlayers = value), title: const Text('Allow same player in different teams', style: TextStyle(fontWeight: FontWeight.w900))),
      if (needsTeams) ...[
        _Pill('Team ${_teamNames.length + 1} of $_teamTarget'),
        _Input(label: 'Team name', controller: _teamName),
        FilledButton.icon(onPressed: _addTeam, icon: const Icon(Icons.add_rounded), label: const Text('Add Team')),
      ] else if (nextTeamForPlayer != null) ...[
        _Pill('$nextTeamForPlayer player ${(_playersByTeam[nextTeamForPlayer]?.length ?? 0) + 1} of $_playerTarget'),
        _Input(label: 'User ID / Public ID / Custom ID', controller: _playerId),
        FilledButton.icon(onPressed: () => _addPlayer(nextTeamForPlayer), icon: const Icon(Icons.person_add_rounded), label: const Text('Fetch & Add Player')),
      ] else ...[
        _FixturePreview(fixtures: _fixtures()),
        FilledButton.icon(onPressed: _saving ? null : _saveTournament, icon: const Icon(Icons.save_rounded), label: Text(_saving ? 'Saving...' : 'Save Tournament')),
      ],
      const SizedBox(height: 12),
      Wrap(spacing: 7, runSpacing: 7, children: _teamNames.map((team) => Chip(label: Text('$team (${_playersByTeam[team]?.length ?? 0}/$_playerTarget)'))).toList()),
    ]);
  }

  Widget _matches() {
    final tournament = _selectedTournament;
    if (tournament == null) return const SizedBox.shrink();
    return ListView(physics: const BouncingScrollPhysics(), children: [
      for (final fixture in tournament.fixtures)
        _Tile(icon: Icons.sports_cricket_rounded, title: '${fixture.teamA.name} vs ${fixture.teamB.name}', subtitle: '${tournament.overs} overs • ${tournament.wickets} wickets', onTap: () => setState(() { _selectedFixture = fixture; _activeMatchId = null; _step = _FlowStep.toss; })),
    ]);
  }

  Widget _quick() {
    return ListView(physics: const BouncingScrollPhysics(), children: [
      _Input(label: 'Team A', controller: _quickA),
      _Input(label: 'Team B', controller: _quickB),
      Row(children: [Expanded(child: _Input(label: 'Players/team', controller: _playersPerTeam, number: true)), const SizedBox(width: 8), Expanded(child: _Input(label: 'Wickets', controller: _wickets, number: true))]),
      _Input(label: 'Overs', controller: _overs, number: true),
      FilledButton.icon(onPressed: _makeQuickFixture, icon: const Icon(Icons.play_arrow_rounded), label: const Text('Continue to Toss')),
    ]);
  }

  Widget _toss() {
    final fixture = _selectedFixture;
    if (fixture == null) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _MatchCard(fixture: fixture),
      const SizedBox(height: 12),
      const _Section('Who won the toss?'),
      Row(children: [Expanded(child: _Choice(label: fixture.teamA.name, selected: _tossWinner?.id == fixture.teamA.id, onTap: () => setState(() => _tossWinner = fixture.teamA))), const SizedBox(width: 8), Expanded(child: _Choice(label: fixture.teamB.name, selected: _tossWinner?.id == fixture.teamB.id, onTap: () => setState(() => _tossWinner = fixture.teamB)))]),
      const SizedBox(height: 12),
      const _Section('Decision'),
      Row(children: [Expanded(child: _Choice(label: 'Bat', selected: _decision == _TossDecision.bat, onTap: () => setState(() => _decision = _TossDecision.bat))), const SizedBox(width: 8), Expanded(child: _Choice(label: 'Ball', selected: _decision == _TossDecision.ball, onTap: () => setState(() => _decision = _TossDecision.ball)))]),
      const Spacer(),
      FilledButton.icon(onPressed: _tossWinner == null || _decision == null || _saving ? null : _confirmToss, icon: const Icon(Icons.check_circle_rounded), label: Text(_saving ? 'Saving toss...' : 'Confirm Toss')),
    ]);
  }

  Widget _lineups() {
    final fixture = _selectedFixture;
    if (fixture == null || _tossWinner == null || _decision == null) return const SizedBox.shrink();
    final batting = _battingTeam(fixture);
    final bowling = batting.id == fixture.teamA.id ? fixture.teamB : fixture.teamA;
    return ListView(physics: const BouncingScrollPhysics(), children: [
      _Pill('${_tossWinner!.name} won toss and chose to ${_decision == _TossDecision.bat ? 'bat' : 'ball'}'),
      _Picker(title: 'Opening batsman 1', players: batting.players, selected: _striker, onSelected: (player) => setState(() => _striker = player)),
      _Picker(title: 'Opening batsman 2', players: batting.players.where((p) => p.id != _striker?.id).toList(), selected: _nonStriker, onSelected: (player) => setState(() => _nonStriker = player)),
      _Picker(title: 'Opening bowler', players: bowling.players, selected: _bowler, onSelected: (player) => setState(() => _bowler = player)),
      FilledButton.icon(onPressed: _striker == null || _nonStriker == null || _bowler == null || _saving ? null : _startMatch, icon: const Icon(Icons.sports_cricket_rounded), label: Text(_saving ? 'Starting...' : 'Start Match')),
    ]);
  }

  void _addTeam() {
    final value = _teamName.text.trim();
    if (value.isEmpty || _teamNames.contains(value)) return;
    setState(() { _teamNames.add(value); _playersByTeam[value] = <StumpsPlayer>[]; _teamName.clear(); });
  }

  void _addPlayer(String team) {
    final id = _playerId.text.trim();
    if (id.isEmpty) return;
    if (!_allowDuplicatePlayers && _playersByTeam.values.expand((e) => e).any((p) => p.id == id)) {
      RoomToast.show(context, 'Player already exists in another team');
      return;
    }
    setState(() { _playersByTeam[team]!.add(StumpsPlayer(id: id, name: 'User ${id.replaceAll(RegExp(r'[^0-9A-Za-z]'), '')}')); _playerId.clear(); });
  }

  List<StumpsFixture> _fixtures() {
    final teams = _teamNames.map((name) => StumpsTeam(id: name.toLowerCase().replaceAll(' ', '_'), name: name, players: _playersByTeam[name] ?? const <StumpsPlayer>[])).toList();
    final fixtures = <StumpsFixture>[];
    var round = 1;
    for (var repeat = 0; repeat < _matchesVsEachValue; repeat++) {
      for (var i = 0; i < teams.length; i++) {
        for (var j = i + 1; j < teams.length; j++) {
          fixtures.add(StumpsFixture(id: 'fx_${repeat}_${i}_$j', teamA: teams[i], teamB: teams[j], round: round++));
        }
      }
    }
    fixtures.shuffle(math.Random(7));
    return fixtures.take(math.max(1, _matchesPerTeamValue * teams.length ~/ 2)).toList();
  }

  Future<void> _saveTournament() async {
    setState(() => _saving = true);
    try {
      final teams = _teamNames.map((name) => StumpsTeam(id: name.toLowerCase().replaceAll(' ', '_'), name: name, players: _playersByTeam[name] ?? const <StumpsPlayer>[])).toList();
      final fixtures = _fixtures();
      final response = await _repository.saveTournament(
        roomId: widget.roomId,
        name: _name.text.trim().isEmpty ? 'Cricket Tournament' : _name.text.trim(),
        teamCount: teams.length,
        playersPerTeam: _playerTarget,
        overs: _oversValue,
        wickets: _wicketsValue,
        matchesPerTeam: _matchesPerTeamValue,
        matchesVsEachTeam: _matchesVsEachValue,
        allowSamePlayerAcrossTeams: _allowDuplicatePlayers,
        teams: teams.map((team) => team.toJson()).toList(),
        fixtures: fixtures.map((fixture) => fixture.toJson()).toList(),
      );
      final tournament = StumpsTournament.fromApi(response);
      if (!mounted) return;
      setState(() {
        _tournaments = [tournament, ..._tournaments.where((item) => item.backendId != tournament.backendId)];
        _selectedTournament = tournament;
        _step = _FlowStep.home;
        _saving = false;
      });
      RoomToast.show(context, '${tournament.name} saved');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      RoomToast.show(context, error.toString());
    }
  }

  Future<void> _deleteTournament(StumpsTournament tournament) async {
    final backendId = tournament.backendId;
    if (backendId == null) return;
    setState(() => _saving = true);
    try {
      await _repository.deleteTournament(roomId: widget.roomId, tournamentId: backendId, reason: 'Deleted from Cricket Mode');
      if (!mounted) return;
      setState(() {
        _tournaments = _tournaments.where((item) => item.backendId != backendId).toList();
        if (_selectedTournament?.backendId == backendId) _selectedTournament = null;
        _saving = false;
      });
      RoomToast.show(context, '${tournament.name} deleted');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      RoomToast.show(context, error.toString());
    }
  }

  void _makeQuickFixture() {
    final a = _quickTeam(_quickA.text.trim().isEmpty ? 'Team A' : _quickA.text.trim(), 'qa');
    final b = _quickTeam(_quickB.text.trim().isEmpty ? 'Team B' : _quickB.text.trim(), 'qb');
    setState(() { _selectedFixture = StumpsFixture(id: 'quick_${DateTime.now().millisecondsSinceEpoch}', teamA: a, teamB: b, round: 1); _selectedTournament = null; _activeMatchId = null; _step = _FlowStep.toss; });
  }

  StumpsTeam _quickTeam(String name, String prefix) => StumpsTeam(id: prefix, name: name, players: List<StumpsPlayer>.generate(_playerTarget, (i) => StumpsPlayer(id: '${prefix}_${i + 1}', name: '$name P${i + 1}')));

  StumpsTeam _battingTeam(StumpsFixture fixture) {
    if (_decision == _TossDecision.bat) return _tossWinner!;
    return _tossWinner!.id == fixture.teamA.id ? fixture.teamB : fixture.teamA;
  }

  Future<void> _confirmToss() async {
    final fixture = _selectedFixture;
    final tossWinner = _tossWinner;
    final decision = _decision;
    if (fixture == null || tossWinner == null || decision == null) return;
    setState(() => _saving = true);
    try {
      final match = await _repository.createMatch(
        roomId: widget.roomId,
        tournamentId: _selectedTournament?.backendId,
        isQuickMatch: _selectedTournament == null,
        teamA: fixture.teamA.toJson(),
        teamB: fixture.teamB.toJson(),
      );
      final matchId = _asInt(match['id']);
      if (matchId == null) throw Exception('Cricket match id missing from backend');
      await _repository.setToss(
        roomId: widget.roomId,
        matchId: matchId,
        tossWinnerTeamId: tossWinner.id,
        decision: decision.name,
      );
      if (!mounted) return;
      setState(() {
        _activeMatchId = matchId;
        _saving = false;
        _step = _FlowStep.lineups;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      RoomToast.show(context, error.toString());
    }
  }

  Future<void> _startMatch() async {
    final fixture = _selectedFixture;
    final matchId = _activeMatchId;
    if (!widget.canManage || fixture == null || matchId == null || _striker == null || _nonStriker == null || _bowler == null) return;
    final batting = _battingTeam(fixture);
    final bowling = batting.id == fixture.teamA.id ? fixture.teamB : fixture.teamA;
    setState(() => _saving = true);
    try {
      await _repository.setLineup(
        roomId: widget.roomId,
        matchId: matchId,
        battingTeamId: batting.id,
        bowlingTeamId: bowling.id,
        strikerPlayerId: _striker!.id,
        nonStrikerPlayerId: _nonStriker!.id,
        bowlerPlayerId: _bowler!.id,
      );
      if (!mounted) return;
      widget.onBackgroundChanged(cricketStumpsPitchBackgroundTheme);
      CricketRoomModeSignal.activate(widget.roomId);
      widget.onSystemMessage?.call('${_tossWinner!.name} won the toss and chose to ${_decision == _TossDecision.bat ? 'bat' : 'ball'}. Seat 3 is now the Umpire/scorer seat.');
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      RoomToast.show(context, error.toString());
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle, required this.canBack, required this.onBack});
  final String title, subtitle;
  final bool canBack;
  final VoidCallback onBack;
  @override Widget build(BuildContext context) => Row(children: [if (canBack) IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded)), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: RoomColors.plum, fontSize: 21, fontWeight: FontWeight.w900)), Text(subtitle, style: const TextStyle(color: Color(0xFF7B7088), fontSize: 11.5, fontWeight: FontWeight.w800))]))]);
}

class _Section extends StatelessWidget { const _Section(this.text); final String text; @override Widget build(BuildContext context) => Text(text, style: const TextStyle(color: RoomColors.plum, fontWeight: FontWeight.w900)); }
class _Pill extends StatelessWidget { const _Pill(this.text); final String text; @override Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: const Color(0xFFE8FFF0), borderRadius: BorderRadius.circular(999)), child: Text(text, style: const TextStyle(color: Color(0xFF0E8F54), fontWeight: FontWeight.w900))); }

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.subtitle, this.onTap, this.trailing});
  final IconData icon; final String title; final String subtitle; final VoidCallback? onTap; final Widget? trailing;
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 9), child: Material(color: Colors.white, borderRadius: BorderRadius.circular(20), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [GradientIconBox(icon: icon, colors: const [Color(0xFF0E8F54), Color(0xFF86FF9D)], size: 42), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: RoomColors.plum, fontWeight: FontWeight.w900)), Text(subtitle, style: const TextStyle(color: Color(0xFF81758C), fontSize: 11, fontWeight: FontWeight.w800))])), trailing ?? const Icon(Icons.chevron_right_rounded)])))));
}

class _Input extends StatelessWidget { const _Input({required this.label, required this.controller, this.number = false}); final String label; final TextEditingController controller; final bool number; @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 9), child: TextField(controller: controller, keyboardType: number ? TextInputType.number : TextInputType.text, decoration: InputDecoration(labelText: label, filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)))); }

class _FixturePreview extends StatelessWidget { const _FixturePreview({required this.fixtures}); final List<StumpsFixture> fixtures; @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const _Section('Randomized matches'), const SizedBox(height: 8), for (final f in fixtures) _Tile(icon: Icons.sports_cricket_rounded, title: '${f.teamA.name} vs ${f.teamB.name}', subtitle: 'Round ${f.round}', onTap: null)]); }
class _MatchCard extends StatelessWidget { const _MatchCard({required this.fixture}); final StumpsFixture fixture; @override Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF061B0D), Color(0xFF0E5A31)]), borderRadius: BorderRadius.circular(24)), child: Text('${fixture.teamA.name} vs ${fixture.teamB.name}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))); }
class _Choice extends StatelessWidget { const _Choice({required this.label, required this.selected, required this.onTap}); final String label; final bool selected; final VoidCallback onTap; @override Widget build(BuildContext context) => Material(color: selected ? const Color(0xFF0E8F54) : Colors.white, borderRadius: BorderRadius.circular(16), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Padding(padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8), child: Center(child: Text(label, style: TextStyle(color: selected ? Colors.white : RoomColors.plum, fontWeight: FontWeight.w900)))))); }
class _Picker extends StatelessWidget { const _Picker({required this.title, required this.players, required this.selected, required this.onSelected}); final String title; final List<StumpsPlayer> players; final StumpsPlayer? selected; final ValueChanged<StumpsPlayer> onSelected; @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_Section(title), const SizedBox(height: 7), Wrap(spacing: 7, runSpacing: 7, children: players.map((p) => ChoiceChip(selected: selected?.id == p.id, label: Text(p.name), onSelected: (_) => onSelected(p))).toList()), const SizedBox(height: 12)]); }
class _ErrorCard extends StatelessWidget { const _ErrorCard({required this.message, required this.onRetry}); final String message; final VoidCallback onRetry; @override Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFFEEF0), borderRadius: BorderRadius.circular(18)), child: Row(children: [const Icon(Icons.error_outline_rounded, color: RoomColors.coral), const SizedBox(width: 8), Expanded(child: Text(message, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: RoomColors.plum, fontWeight: FontWeight.w800))), TextButton(onPressed: onRetry, child: const Text('Retry'))])); }

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
