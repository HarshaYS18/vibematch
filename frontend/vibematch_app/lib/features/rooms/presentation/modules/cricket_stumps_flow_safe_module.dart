import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/ui/vm_motion.dart';
import '../../data/cricket_stumps_flow_repository.dart';
import '../widgets/cricket_room_backgrounds.dart';
import '../widgets/room_theme.dart';
import 'cricket_room_mode_signal.dart';

class CricketStumpsFlowSafeModule {
  const CricketStumpsFlowSafeModule._();

  static Future<void> open({
    required BuildContext context,
    required String roomId,
    required String roomName,
    required bool canManage,
    required RoomBackgroundTheme previousBackground,
    required ValueChanged<RoomBackgroundTheme> onBackgroundChanged,
    required ValueChanged<CricketQuickMatchSetup> onMatchStarted,
    ValueChanged<String>? onSystemMessage,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: VmMotion.sheetAnimationStyle,
      builder: (_) => _CricketSetupSheet(
        roomId: roomId,
        roomName: roomName,
        canManage: canManage,
        onBackgroundChanged: onBackgroundChanged,
        onMatchStarted: onMatchStarted,
        onSystemMessage: onSystemMessage,
      ),
    );
  }
}

enum _SetupStep { teams, toss, lineup }
enum _TossDecision { bat, ball }

class _PlayerDraft {
  const _PlayerDraft({required this.id, required this.name});
  final String id;
  final String name;
}

class _TeamDraft {
  const _TeamDraft({required this.id, required this.name, required this.players});
  final String id;
  final String name;
  final List<_PlayerDraft> players;
}

class _CricketSetupSheet extends StatefulWidget {
  const _CricketSetupSheet({
    required this.roomId,
    required this.roomName,
    required this.canManage,
    required this.onBackgroundChanged,
    required this.onMatchStarted,
    this.onSystemMessage,
  });

  final String roomId;
  final String roomName;
  final bool canManage;
  final ValueChanged<RoomBackgroundTheme> onBackgroundChanged;
  final ValueChanged<CricketQuickMatchSetup> onMatchStarted;
  final ValueChanged<String>? onSystemMessage;

  @override
  State<_CricketSetupSheet> createState() => _CricketSetupSheetState();
}

class _CricketSetupSheetState extends State<_CricketSetupSheet> {
  final CricketStumpsFlowRepository _repository = const CricketStumpsFlowRepository();
  final TextEditingController _teamA = TextEditingController();
  final TextEditingController _teamB = TextEditingController();
  final TextEditingController _overs = TextEditingController(text: '5');
  final List<TextEditingController> _teamAPlayers = <TextEditingController>[];
  final List<TextEditingController> _teamBPlayers = <TextEditingController>[];

  _SetupStep _step = _SetupStep.teams;
  int _playersPerTeam = 5;
  int _wickets = 4;
  int? _matchId;
  bool _saving = false;
  _TeamDraft? _draftA;
  _TeamDraft? _draftB;
  _TeamDraft? _tossWinner;
  _TossDecision? _decision;
  _PlayerDraft? _striker;
  _PlayerDraft? _nonStriker;
  _PlayerDraft? _bowler;

  int get _oversValue => math.max(1, int.tryParse(_overs.text) ?? 5);

  @override
  void initState() {
    super.initState();
    _syncPlayerControllers();
  }

  @override
  void dispose() {
    _teamA.dispose();
    _teamB.dispose();
    _overs.dispose();
    for (final controller in _teamAPlayers) {
      controller.dispose();
    }
    for (final controller in _teamBPlayers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncPlayerControllers() {
    void sync(List<TextEditingController> controllers) {
      while (controllers.length < _playersPerTeam) {
        controllers.add(TextEditingController());
      }
      while (controllers.length > _playersPerTeam) {
        controllers.removeLast().dispose();
      }
    }
    sync(_teamAPlayers);
    sync(_teamBPlayers);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return AnimatedPadding(
      duration: VmMotion.sheetReverseDuration,
      curve: VmMotion.standardCurve,
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
          child: Container(
            clipBehavior: Clip.antiAlias,
            padding: EdgeInsets.fromLTRB(14, 8, 14, media.padding.bottom + 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF9F8F2),
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SheetHandle(width: 48),
                const SizedBox(height: 10),
                _Header(
                  title: _title,
                  subtitle: _subtitle,
                  canBack: _step != _SetupStep.teams,
                  onBack: () => setState(() => _step = _SetupStep.teams),
                ),
                const SizedBox(height: 12),
                Flexible(child: _body()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _title => switch (_step) {
    _SetupStep.teams => 'Quick Cricket Match',
    _SetupStep.toss => 'Toss',
    _SetupStep.lineup => 'Opening Lineup',
  };

  String get _subtitle => switch (_step) {
    _SetupStep.teams => 'Set team names and player names again.',
    _SetupStep.toss => 'Choose toss winner and bat/ball decision.',
    _SetupStep.lineup => 'Pick striker, non-striker and bowler.',
  };

  Widget _body() {
    return switch (_step) {
      _SetupStep.teams => _teamsStep(),
      _SetupStep.toss => _tossStep(),
      _SetupStep.lineup => _lineupStep(),
    };
  }

  Widget _teamsStep() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _Input(label: 'Team A', controller: _teamA),
        _Input(label: 'Team B', controller: _teamB),
        Row(
          children: [
            Expanded(
              child: _NumberDropdown(
                label: 'Players/team',
                value: _playersPerTeam,
                max: 12,
                onChanged: (value) {
                  setState(() {
                    _playersPerTeam = value;
                    if (_wickets > value) _wickets = value;
                    _syncPlayerControllers();
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _NumberDropdown(
                label: 'Wickets',
                value: _wickets,
                max: 12,
                onChanged: (value) => setState(() => _wickets = value),
              ),
            ),
          ],
        ),
        _PlayerList(title: 'Team A players', controllers: _teamAPlayers),
        _PlayerList(title: 'Team B players', controllers: _teamBPlayers),
        _Input(label: 'Overs', controller: _overs, number: true),
        FilledButton.icon(
          onPressed: widget.canManage ? _continueToToss : null,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Continue to Toss'),
        ),
      ],
    );
  }

  Widget _tossStep() {
    final teamA = _draftA;
    final teamB = _draftB;
    if (teamA == null || teamB == null) return const SizedBox.shrink();
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _MatchCard(label: '${teamA.name} vs ${teamB.name}'),
        const SizedBox(height: 12),
        const _Section('Who won the toss?'),
        const SizedBox(height: 7),
        Row(
          children: [
            Expanded(
              child: _Choice(
                label: teamA.name,
                selected: _tossWinner?.id == teamA.id,
                onTap: () => setState(() => _tossWinner = teamA),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Choice(
                label: teamB.name,
                selected: _tossWinner?.id == teamB.id,
                onTap: () => setState(() => _tossWinner = teamB),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _Section('Decision'),
        const SizedBox(height: 7),
        Row(
          children: [
            Expanded(
              child: _Choice(
                label: 'Bat',
                selected: _decision == _TossDecision.bat,
                onTap: () => setState(() => _decision = _TossDecision.bat),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Choice(
                label: 'Ball',
                selected: _decision == _TossDecision.ball,
                onTap: () => setState(() => _decision = _TossDecision.ball),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _tossWinner == null || _decision == null || _saving ? null : _confirmToss,
          icon: const Icon(Icons.check_circle_rounded),
          label: Text(_saving ? 'Saving toss...' : 'Confirm Toss'),
        ),
      ],
    );
  }

  Widget _lineupStep() {
    final teamA = _draftA;
    final teamB = _draftB;
    if (teamA == null || teamB == null || _tossWinner == null || _decision == null) {
      return const SizedBox.shrink();
    }
    final batting = _battingTeam(teamA, teamB);
    final bowling = batting.id == teamA.id ? teamB : teamA;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _Pill('${_tossWinner!.name} won toss and chose to ${_decision == _TossDecision.bat ? 'bat' : 'ball'}'),
        _Picker(title: 'Opening batsman 1', players: batting.players, selected: _striker, onSelected: (player) => setState(() => _striker = player)),
        _Picker(title: 'Opening batsman 2', players: batting.players.where((player) => player.id != _striker?.id).toList(), selected: _nonStriker, onSelected: (player) => setState(() => _nonStriker = player)),
        _Picker(title: 'Opening bowler', players: bowling.players, selected: _bowler, onSelected: (player) => setState(() => _bowler = player)),
        FilledButton.icon(
          onPressed: _striker == null || _nonStriker == null || _bowler == null || _saving ? null : _startMatch,
          icon: const Icon(Icons.sports_cricket_rounded),
          label: Text(_saving ? 'Starting...' : 'Start Match'),
        ),
      ],
    );
  }

  void _continueToToss() {
    setState(() {
      _draftA = _teamDraft(_teamA.text.trim().isEmpty ? 'Team A' : _teamA.text.trim(), 'qa', _teamAPlayers);
      _draftB = _teamDraft(_teamB.text.trim().isEmpty ? 'Team B' : _teamB.text.trim(), 'qb', _teamBPlayers);
      _matchId = null;
      _tossWinner = null;
      _decision = null;
      _striker = null;
      _nonStriker = null;
      _bowler = null;
      _step = _SetupStep.toss;
    });
  }

  _TeamDraft _teamDraft(String name, String prefix, List<TextEditingController> controllers) {
    return _TeamDraft(
      id: prefix,
      name: name,
      players: List<_PlayerDraft>.generate(_playersPerTeam, (index) {
        final typedName = index < controllers.length ? controllers[index].text.trim() : '';
        return _PlayerDraft(id: '${prefix}_${index + 1}', name: typedName.isEmpty ? 'Player ${index + 1}' : typedName);
      }),
    );
  }

  Map<String, dynamic> _teamJson(_TeamDraft team) => {
        'id': team.id,
        'name': team.name,
        'players': team.players.map((player) => {'id': player.id, 'name': player.name}).toList(),
        'quick_match_rules': {
          'overs_per_innings': _oversValue,
          'wickets_per_side': _wickets,
          'players_per_team': _playersPerTeam,
        },
      };

  CricketQuickMatchTeamSetup _signalTeam(_TeamDraft team) {
    return CricketQuickMatchTeamSetup(
      id: team.id,
      name: team.name,
      players: team.players.map((player) => CricketQuickMatchPlayerSetup(id: player.id, name: player.name)).toList(),
    );
  }

  _TeamDraft _battingTeam(_TeamDraft teamA, _TeamDraft teamB) {
    if (_decision == _TossDecision.bat) return _tossWinner!;
    return _tossWinner!.id == teamA.id ? teamB : teamA;
  }

  Future<void> _confirmToss() async {
    final teamA = _draftA;
    final teamB = _draftB;
    final tossWinner = _tossWinner;
    final decision = _decision;
    if (teamA == null || teamB == null || tossWinner == null || decision == null) return;
    setState(() => _saving = true);
    try {
      final match = await _repository.createMatch(
        roomId: widget.roomId,
        tournamentId: null,
        isQuickMatch: true,
        teamA: _teamJson(teamA),
        teamB: _teamJson(teamB),
      );
      final matchId = _asInt(match['id']);
      if (matchId == null) throw Exception('Cricket match id missing from backend');
      await _repository.setToss(roomId: widget.roomId, matchId: matchId, tossWinnerTeamId: tossWinner.id, decision: decision.name);
      if (!mounted) return;
      setState(() {
        _matchId = matchId;
        _saving = false;
        _step = _SetupStep.lineup;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      RoomToast.show(context, error.toString());
    }
  }

  Future<void> _startMatch() async {
    final teamA = _draftA;
    final teamB = _draftB;
    final matchId = _matchId;
    if (!widget.canManage || teamA == null || teamB == null || matchId == null || _striker == null || _nonStriker == null || _bowler == null) return;
    final batting = _battingTeam(teamA, teamB);
    final bowling = batting.id == teamA.id ? teamB : teamA;
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
      widget.onBackgroundChanged(cricketFloodlightArenaBackgroundTheme);
      final setup = CricketQuickMatchSetup(
        roomId: widget.roomId,
        roomName: widget.roomName,
        teamA: _signalTeam(teamA),
        teamB: _signalTeam(teamB),
        overs: _oversValue,
        wickets: _wickets,
        battingTeamId: batting.id,
        bowlingTeamId: bowling.id,
        strikerId: _striker!.id,
        nonStrikerId: _nonStriker!.id,
        bowlerId: _bowler!.id,
      );
      widget.onMatchStarted(setup);
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
  final String title;
  final String subtitle;
  final bool canBack;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (canBack) IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: RoomColors.plum, fontSize: 21, fontWeight: FontWeight.w900)),
              if (subtitle.trim().isNotEmpty) Text(subtitle, style: const TextStyle(color: Color(0xFF7B7088), fontSize: 11.5, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(color: RoomColors.plum, fontWeight: FontWeight.w900));
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: const Color(0xFFE8FFF0), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: const TextStyle(color: Color(0xFF0E8F54), fontWeight: FontWeight.w900)),
      );
}

class _PlayerList extends StatelessWidget {
  const _PlayerList({required this.title, required this.controllers});
  final String title;
  final List<TextEditingController> controllers;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE8DED4))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: RoomColors.plum, fontSize: 13, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          for (var index = 0; index < controllers.length; index += 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  SizedBox(width: 28, child: Text('${index + 1}.', style: const TextStyle(color: Color(0xFF81758C), fontWeight: FontWeight.w900))),
                  Expanded(child: _Input(label: 'Player ${index + 1} name', controller: controllers[index], dense: true)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _NumberDropdown extends StatelessWidget {
  const _NumberDropdown({required this.label, required this.value, required this.max, required this.onChanged});
  final String label;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(1, max).toInt();
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: DropdownButtonFormField<int>(
        initialValue: safeValue,
        decoration: InputDecoration(labelText: label, filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
        items: List<DropdownMenuItem<int>>.generate(max, (index) => DropdownMenuItem<int>(value: index + 1, child: Text('${index + 1}'))),
        onChanged: (selected) {
          if (selected != null) onChanged(selected);
        },
      ),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({required this.label, required this.controller, this.number = false, this.dense = false});
  final String label;
  final TextEditingController controller;
  final bool number;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: dense ? 0 : 9),
      child: TextField(
        controller: controller,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          isDense: dense,
          filled: true,
          fillColor: dense ? const Color(0xFFF9F8F2) : Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(dense ? 14 : 16), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF061B0D), Color(0xFF0E5A31)]), borderRadius: BorderRadius.circular(24)),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
      );
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? const Color(0xFF0E8F54) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
            child: Center(child: Text(label, style: TextStyle(color: selected ? Colors.white : RoomColors.plum, fontWeight: FontWeight.w900))),
          ),
        ),
      );
}

class _Picker extends StatelessWidget {
  const _Picker({required this.title, required this.players, required this.selected, required this.onSelected});
  final String title;
  final List<_PlayerDraft> players;
  final _PlayerDraft? selected;
  final ValueChanged<_PlayerDraft> onSelected;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Section(title),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: players.map((player) => ChoiceChip(selected: selected?.id == player.id, label: Text(player.name), onSelected: (_) => onSelected(player))).toList(),
          ),
          const SizedBox(height: 12),
        ],
      );
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
