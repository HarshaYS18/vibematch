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
      builder: (_) => _QuickCricketFlowSheet(
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

class StumpsTeam {
  const StumpsTeam({
    required this.id,
    required this.name,
    required this.players,
  });

  final String id;
  final String name;
  final List<StumpsPlayer> players;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'players': players.map((player) => player.toJson()).toList(),
      };
}

class StumpsPlayer {
  const StumpsPlayer({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class StumpsFixture {
  const StumpsFixture({
    required this.id,
    required this.teamA,
    required this.teamB,
    required this.round,
  });

  final String id;
  final StumpsTeam teamA;
  final StumpsTeam teamB;
  final int round;
}

enum _FlowStep { quick, toss, lineups }

enum _TossDecision { bat, ball }

class _QuickCricketFlowSheet extends StatefulWidget {
  const _QuickCricketFlowSheet({
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
  State<_QuickCricketFlowSheet> createState() => _QuickCricketFlowSheetState();
}

class _QuickCricketFlowSheetState extends State<_QuickCricketFlowSheet> {
  final CricketStumpsFlowRepository _repository =
      const CricketStumpsFlowRepository();

  _FlowStep _step = _FlowStep.quick;
  StumpsFixture? _selectedFixture;
  StumpsTeam? _tossWinner;
  _TossDecision? _decision;
  StumpsPlayer? _striker;
  StumpsPlayer? _nonStriker;
  StumpsPlayer? _bowler;
  int? _activeMatchId;
  bool _saving = false;

  final _quickA = TextEditingController();
  final _quickB = TextEditingController();
  int _playersPerTeamValue = 5;
  final _overs = TextEditingController(text: '5');
  int _wicketsValueState = 4;
  final List<TextEditingController> _teamAPlayerControllers = <TextEditingController>[];
  final List<TextEditingController> _teamBPlayerControllers = <TextEditingController>[];

  int get _playerTarget => _playersPerTeamValue;

  int get _oversValue => math.max(1, int.tryParse(_overs.text) ?? 5);

  int get _wicketsValue => _wicketsValueState;

  @override
  void initState() {
    super.initState();
    _syncPlayerControllers();
  }

  void _syncPlayerControllers() {
    void sync(List<TextEditingController> controllers) {
      while (controllers.length < _playerTarget) {
        controllers.add(TextEditingController());
      }
      while (controllers.length > _playerTarget) {
        controllers.removeLast().dispose();
      }
    }

    sync(_teamAPlayerControllers);
    sync(_teamBPlayerControllers);
  }

  @override
  void dispose() {
    _quickA.dispose();
    _quickB.dispose();
    _overs.dispose();
    for (final controller in _teamAPlayerControllers) {
      controller.dispose();
    }
    for (final controller in _teamBPlayerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.9,
      padding: EdgeInsets.fromLTRB(
        14,
        8,
        14,
        MediaQuery.paddingOf(context).bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF9F8F2),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const SheetHandle(width: 48),
          const SizedBox(height: 10),
          _Header(
            title: _title,
            subtitle: _subtitle,
            canBack: _step != _FlowStep.quick,
            onBack: () => setState(() => _step = _FlowStep.quick),
          ),
          const SizedBox(height: 12),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  String get _title => switch (_step) {
        _FlowStep.quick => 'Quick Cricket Match',
        _FlowStep.toss => 'Toss',
        _FlowStep.lineups => 'Opening Lineup',
      };

  String get _subtitle => switch (_step) {
        _FlowStep.quick => '',
        _FlowStep.toss => 'Choose toss winner and bat/ball decision.',
        _FlowStep.lineups =>
          'Pick two opening batsmen and one opening bowler.',
      };

  Widget _body() {
    return switch (_step) {
      _FlowStep.quick => _quick(),
      _FlowStep.toss => _toss(),
      _FlowStep.lineups => _lineups(),
    };
  }

  Widget _quick() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        _Input(label: 'Team A', controller: _quickA),
        _Input(label: 'Team B', controller: _quickB),
        Row(
          children: [
            Expanded(
              child: _NumberDropdown(
                label: 'Players/team',
                value: _playersPerTeamValue,
                max: 12,
                onChanged: (value) {
                  setState(() {
                    _playersPerTeamValue = value;
                    if (_wicketsValueState > value) {
                      _wicketsValueState = value;
                    }
                    _syncPlayerControllers();
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _NumberDropdown(
                label: 'Wickets',
                value: _wicketsValueState,
                max: 12,
                onChanged: (value) {
                  setState(() {
                    _wicketsValueState = value;
                  });
                },
              ),
            ),
          ],
        ),
        _PlayerNameList(
          title: 'Team A players',
          controllers: _teamAPlayerControllers,
        ),
        _PlayerNameList(
          title: 'Team B players',
          controllers: _teamBPlayerControllers,
        ),
        _Input(label: 'Overs', controller: _overs, number: true),
        FilledButton.icon(
          onPressed: widget.canManage ? _makeQuickFixture : null,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Continue to Toss'),
        ),
      ],
    );
  }

  Widget _toss() {
    final fixture = _selectedFixture;
    if (fixture == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MatchCard(fixture: fixture),
        const SizedBox(height: 12),
        const _Section('Who won the toss?'),
        Row(
          children: [
            Expanded(
              child: _Choice(
                label: fixture.teamA.name,
                selected: _tossWinner?.id == fixture.teamA.id,
                onTap: () => setState(() => _tossWinner = fixture.teamA),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Choice(
                label: fixture.teamB.name,
                selected: _tossWinner?.id == fixture.teamB.id,
                onTap: () => setState(() => _tossWinner = fixture.teamB),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _Section('Decision'),
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
        const Spacer(),
        FilledButton.icon(
          onPressed:
              _tossWinner == null || _decision == null || _saving
                  ? null
                  : _confirmToss,
          icon: const Icon(Icons.check_circle_rounded),
          label: Text(_saving ? 'Saving toss...' : 'Confirm Toss'),
        ),
      ],
    );
  }

  Widget _lineups() {
    final fixture = _selectedFixture;
    if (fixture == null || _tossWinner == null || _decision == null) {
      return const SizedBox.shrink();
    }

    final batting = _battingTeam(fixture);
    final bowling = batting.id == fixture.teamA.id ? fixture.teamB : fixture.teamA;

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        _Pill(
          '${_tossWinner!.name} won toss and chose to ${_decision == _TossDecision.bat ? 'bat' : 'ball'}',
        ),
        _Picker(
          title: 'Opening batsman 1',
          players: batting.players,
          selected: _striker,
          onSelected: (player) => setState(() => _striker = player),
        ),
        _Picker(
          title: 'Opening batsman 2',
          players: batting.players
              .where((player) => player.id != _striker?.id)
              .toList(),
          selected: _nonStriker,
          onSelected: (player) => setState(() => _nonStriker = player),
        ),
        _Picker(
          title: 'Opening bowler',
          players: bowling.players,
          selected: _bowler,
          onSelected: (player) => setState(() => _bowler = player),
        ),
        FilledButton.icon(
          onPressed: _striker == null ||
                  _nonStriker == null ||
                  _bowler == null ||
                  _saving
              ? null
              : _startMatch,
          icon: const Icon(Icons.sports_cricket_rounded),
          label: Text(_saving ? 'Starting...' : 'Start Match'),
        ),
      ],
    );
  }

  void _makeQuickFixture() {
    final teamAName =
        _quickA.text.trim().isEmpty ? 'Team A' : _quickA.text.trim();
    final teamBName =
        _quickB.text.trim().isEmpty ? 'Team B' : _quickB.text.trim();

    setState(() {
      _selectedFixture = StumpsFixture(
        id: 'quick_${DateTime.now().millisecondsSinceEpoch}',
        teamA: _quickTeam(teamAName, 'qa', _teamAPlayerControllers),
        teamB: _quickTeam(teamBName, 'qb', _teamBPlayerControllers),
        round: 1,
      );
      _activeMatchId = null;
      _tossWinner = null;
      _decision = null;
      _striker = null;
      _nonStriker = null;
      _bowler = null;
      _step = _FlowStep.toss;
    });
  }

  StumpsTeam _quickTeam(
    String name,
    String prefix,
    List<TextEditingController> playerControllers,
  ) {
    final playerNames = List<String>.generate(_playerTarget, (index) {
      if (index < playerControllers.length) {
        final value = playerControllers[index].text.trim();
        if (value.isNotEmpty) return value;
      }
      return 'Player ${index + 1}';
    });

    return StumpsTeam(
      id: prefix,
      name: name,
      players: List<StumpsPlayer>.generate(
        _playerTarget,
        (index) => StumpsPlayer(
          id: '${prefix}_${index + 1}',
          name: playerNames[index],
        ),
      ),
    );
  }

  CricketQuickMatchTeamSetup _toSignalTeam(StumpsTeam team) {
    return CricketQuickMatchTeamSetup(
      id: team.id,
      name: team.name,
      players: team.players
          .map(
            (player) => CricketQuickMatchPlayerSetup(
              id: player.id,
              name: player.name,
            ),
          )
          .toList(),
    );
  }

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
        tournamentId: null,
        isQuickMatch: true,
        teamA: {
          ...fixture.teamA.toJson(),
          'quick_match_rules': {
            'overs_per_innings': _oversValue,
            'wickets_per_side': _wicketsValue,
            'players_per_team': _playerTarget,
          },
        },
        teamB: {
          ...fixture.teamB.toJson(),
          'quick_match_rules': {
            'overs_per_innings': _oversValue,
            'wickets_per_side': _wicketsValue,
            'players_per_team': _playerTarget,
          },
        },
      );
      final matchId = _asInt(match['id']);
      if (matchId == null) {
        throw Exception('Cricket match id missing from backend');
      }

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
    if (!widget.canManage ||
        fixture == null ||
        matchId == null ||
        _striker == null ||
        _nonStriker == null ||
        _bowler == null) {
      return;
    }

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
      CricketRoomModeSignal.activateWithSetup(
        roomId: widget.roomId,
        setup: CricketQuickMatchSetup(
          roomId: widget.roomId,
          roomName: widget.roomName,
          teamA: _toSignalTeam(fixture.teamA),
          teamB: _toSignalTeam(fixture.teamB),
          overs: _oversValue,
          wickets: _wicketsValue,
          battingTeamId: batting.id,
          bowlingTeamId: bowling.id,
          strikerId: _striker!.id,
          nonStrikerId: _nonStriker!.id,
          bowlerId: _bowler!.id,
        ),
      );
      widget.onSystemMessage?.call(
        '${_tossWinner!.name} won the toss and chose to ${_decision == _TossDecision.bat ? 'bat' : 'ball'}. Seat 3 is now the Umpire/scorer seat.',
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      RoomToast.show(context, error.toString());
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.canBack,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final bool canBack;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (canBack)
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: RoomColors.plum,
                      fontSize: 21,
                      fontWeight: FontWeight.w900)),
              if (subtitle.trim().isNotEmpty)
                Text(subtitle,
                    style: const TextStyle(
                        color: Color(0xFF7B7088),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800)),
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
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            color: RoomColors.plum, fontWeight: FontWeight.w900));
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFE8FFF0),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: const TextStyle(
              color: Color(0xFF0E8F54), fontWeight: FontWeight.w900)),
    );
  }
}


class _PlayerNameList extends StatelessWidget {
  const _PlayerNameList({
    required this.title,
    required this.controllers,
  });

  final String title;
  final List<TextEditingController> controllers;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8DED4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: RoomColors.plum,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < controllers.length; index += 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${index + 1}.',
                      style: const TextStyle(
                        color: Color(0xFF81758C),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: controllers[index],
                      decoration: InputDecoration(
                        hintText: 'Player ${index + 1} name',
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFFF9F8F2),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}


class _NumberDropdown extends StatelessWidget {
  const _NumberDropdown({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

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
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
        items: List<DropdownMenuItem<int>>.generate(
          max,
          (index) {
            final number = index + 1;
            return DropdownMenuItem<int>(
              value: number,
              child: Text('$number'),
            );
          },
        ),
        onChanged: (selected) {
          if (selected != null) onChanged(selected);
        },
      ),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({
    required this.label,
    required this.controller,
    this.number = false,
  });

  final String label;
  final TextEditingController controller;
  final bool number;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: TextField(
        controller: controller,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.fixture});
  final StumpsFixture fixture;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF061B0D), Color(0xFF0E5A31)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        '${fixture.teamA.name} vs ${fixture.teamB.name}',
        style: const TextStyle(
            color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF0E8F54) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: selected ? Colors.white : RoomColors.plum,
                    fontWeight: FontWeight.w900)),
          ),
        ),
      ),
    );
  }
}

class _Picker extends StatelessWidget {
  const _Picker({
    required this.title,
    required this.players,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final List<StumpsPlayer> players;
  final StumpsPlayer? selected;
  final ValueChanged<StumpsPlayer> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(title),
        const SizedBox(height: 7),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: players
              .map((player) => ChoiceChip(
                    selected: selected?.id == player.id,
                    label: Text(player.name),
                    onSelected: (_) => onSelected(player),
                  ))
              .toList(),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}