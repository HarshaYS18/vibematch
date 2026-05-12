import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/room_theme.dart';
import 'cricket_room_mode_module.dart';
import 'cricket_room_mode_registry.dart';

class CricketRoomControlsModule extends StatelessWidget {
  const CricketRoomControlsModule({
    super.key,
    required this.controller,
    required this.canManage,
    required this.onEndMode,
  });

  final CricketRoomModeController controller;
  final bool canManage;
  final VoidCallback onEndMode;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 96, 14, 0),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 170,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xEE07160D),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.30),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF0E8F54), Color(0xFF86FF9D)],
                        ),
                      ),
                      child: const Icon(
                        Icons.sports_cricket_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Cricket CP',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _CricketControlButton(
                  icon: Icons.emoji_events_rounded,
                  label: 'Tournament',
                  enabled: canManage,
                  onTap: () => _openTournamentCreator(context),
                ),
                _CricketControlButton(
                  icon: Icons.table_chart_rounded,
                  label: 'Points Table',
                  enabled: true,
                  onTap: () => _openPointsTable(context),
                ),
                _CricketControlButton(
                  icon: Icons.workspace_premium_rounded,
                  label: 'Result',
                  enabled: true,
                  onTap: () => _openResult(context),
                ),
                _CricketControlButton(
                  icon: Icons.stop_circle_rounded,
                  label: 'End Mode',
                  danger: true,
                  enabled: canManage,
                  onTap: () {
                    CricketRoomModeRegistry.deactivateRoom(
                      roomId: controller.match.roomId,
                    );
                    onEndMode();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openTournamentCreator(BuildContext context) async {
    final config = await CricketRoomModeModule.openTournamentCreator(
      context: context,
      initialConfig: controller.tournament,
    );
    if (config == null) return;
    controller.updateTournament(config);
    if (!context.mounted) return;
    RoomToast.show(context, '${config.name} rules saved');
  }

  void _openPointsTable(BuildContext context) {
    CricketRoomModeModule.openPointsTable(
      context: context,
      rows: _pointsRows(),
    );
  }

  void _openResult(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CricketMatchResultSheet(controller: controller),
    );
  }

  List<CricketPointsRow> _pointsRows() {
    final match = controller.match;
    final snapshot = match.snapshot;
    final teams = controller.tournament.teams.isEmpty
        ? <String>[match.teamA.name, match.teamB.name]
        : controller.tournament.teams;
    final rows = <CricketPointsRow>[];

    for (var index = 0; index < teams.length; index += 1) {
      final isBattingTeam = teams[index] == match.battingTeam.name || index == 0;
      final runsFor = isBattingTeam ? snapshot.runs : math.max(0, snapshot.runs - 8 - (index * 4));
      final runsAgainst = isBattingTeam ? math.max(0, snapshot.runs - 11) : snapshot.runs;
      final balls = math.max(6, snapshot.legalBalls == 0 ? 24 : snapshot.legalBalls);
      rows.add(
        CricketPointsRow(
          teamName: teams[index],
          played: snapshot.legalBalls == 0 ? 0 : 1,
          won: isBattingTeam && snapshot.runs > runsAgainst ? 1 : 0,
          lost: !isBattingTeam && snapshot.runs > runsFor ? 1 : 0,
          tied: 0,
          noResult: 0,
          points: isBattingTeam && snapshot.runs > runsAgainst ? controller.tournament.rules.winPoints : 0,
          runsFor: runsFor,
          ballsFaced: balls,
          runsAgainst: runsAgainst,
          ballsBowled: balls,
          wicketsLost: isBattingTeam ? snapshot.wickets : math.max(0, snapshot.wickets - 1),
          wicketsTaken: isBattingTeam ? math.max(0, snapshot.wickets - 1) : snapshot.wickets,
          form: isBattingTeam ? 'W' : 'L',
        ),
      );
    }

    return rows;
  }
}

class CricketMatchResultSheet extends StatelessWidget {
  const CricketMatchResultSheet({super.key, required this.controller});

  final CricketRoomModeController controller;

  @override
  Widget build(BuildContext context) {
    final match = controller.match;
    final snapshot = match.snapshot;
    final target = match.targetRuns;
    final resultText = _resultText(match, snapshot);

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.58,
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
          const SizedBox(height: 12),
          const Text(
            'Match Result',
            style: TextStyle(
              color: RoomColors.plum,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF061B0D), Color(0xFF0E5A31)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${match.battingTeam.shortName} ${snapshot.runs}/${snapshot.wickets} (${snapshot.oversText})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  target == null ? 'First innings in progress' : 'Target $target',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  resultText,
                  style: const TextStyle(
                    color: Color(0xFFFFD36A),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _ResultMetricRow(
            label: 'Current run rate',
            value: snapshot.currentRunRate.toStringAsFixed(2),
          ),
          _ResultMetricRow(
            label: 'Required run rate',
            value: snapshot.requiredRunRate?.toStringAsFixed(2) ?? '--',
          ),
          _ResultMetricRow(
            label: 'Legal balls',
            value: '${snapshot.legalBalls}',
          ),
          _ResultMetricRow(
            label: 'Recent balls',
            value: snapshot.recentBalls.isEmpty ? '--' : snapshot.recentBalls.join(' '),
          ),
        ],
      ),
    );
  }

  String _resultText(CricketMatchState match, CricketScoreSnapshot snapshot) {
    if (match.status != CricketMatchStatus.completed) {
      if (match.targetRuns == null) return 'Match is live. Result pending.';
      final needed = math.max(0, match.targetRuns! - snapshot.runs);
      if (needed == 0) return '${match.battingTeam.name} reached the target.';
      return '${match.battingTeam.name} need $needed runs.';
    }
    if (match.targetRuns != null && snapshot.runs >= match.targetRuns!) {
      return '${match.battingTeam.name} won the match.';
    }
    return 'Match completed. Final result ready for backend confirmation.';
  }
}

class _ResultMetricRow extends StatelessWidget {
  const _ResultMetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF81758C),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: RoomColors.plum,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CricketControlButton extends StatelessWidget {
  const _CricketControlButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Opacity(
        opacity: enabled ? 1 : 0.48,
        child: Material(
          color: danger
              ? RoomColors.coral.withValues(alpha: 0.88)
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
              child: Row(
                children: [
                  Icon(icon, size: 15, color: Colors.white),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
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
