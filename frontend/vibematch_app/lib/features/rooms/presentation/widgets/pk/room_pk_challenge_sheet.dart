import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/network/vm_failure.dart';
import '../../controllers/room_pk_controller.dart';
import '../../../data/room_pk_api_service.dart';
import '../room_theme.dart';

class RoomPkChallengeSheet extends StatefulWidget {
  const RoomPkChallengeSheet({
    super.key,
    required this.controller,
    required this.canManage,
    required this.cricketModeActive,
  });

  final RoomPkController controller;
  final bool canManage;
  final bool cricketModeActive;

  @override
  State<RoomPkChallengeSheet> createState() => _RoomPkChallengeSheetState();
}

class _RoomPkChallengeSheetState extends State<RoomPkChallengeSheet> {
  List<RoomPkRoomSummary>? _candidates;
  String? _error;
  bool _loading = false;
  int _durationSeconds = 180;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
    if (!widget.controller.pending && !widget.controller.active) {
      unawaited(_loadCandidates());
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    if (mounted) setState(() {});
  }

  Future<void> _loadCandidates() async {
    if (!widget.canManage || widget.cricketModeActive) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final value = await widget.controller.loadCandidates();
      if (!mounted) return;
      setState(() => _candidates = value);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = VmFailurePresentation.messageFor(
          error,
          contentLabel: 'PK rooms',
        );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _error = null);
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = VmFailurePresentation.messageFor(
          error,
          contentLabel: 'PK battle',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final opponent = controller.opponentRoom;
    final surfacedError = _error ?? controller.error;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.74,
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.paddingOf(context).bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: SheetHandle(width: 42)),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: RoomColors.coral.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.flash_on_rounded,
                  color: RoomColors.coral,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Room PK',
                      style: TextStyle(
                        color: RoomColors.plum,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Battle another live room with gift-powered scoring',
                      style: TextStyle(
                        color: Color(0xFF7B6A86),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!widget.canManage)
            const _InfoCard(
              icon: Icons.admin_panel_settings_rounded,
              text: 'Only the room host or admin can start and control PK.',
            )
          else if (widget.cricketModeActive)
            const _InfoCard(
              icon: Icons.sports_cricket_rounded,
              text: 'End Cricket Mode before starting Room PK.',
            )
          else if (controller.isIncomingChallenge && opponent != null)
            _IncomingChallenge(
              opponent: opponent,
              pending: controller.actionPending,
              onAccept: () => _run(controller.accept),
              onDecline: () => _run(controller.decline),
            )
          else if (controller.isOutgoingChallenge && opponent != null)
            _CurrentBattleCard(
              title: 'Challenge sent',
              subtitle:
                  'Waiting for ${opponent.roomName} to accept your PK request.',
              buttonText: 'Cancel challenge',
              pending: controller.actionPending,
              onPressed: () => _run(controller.cancelOrEnd),
            )
          else if (controller.active && opponent != null)
            _CurrentBattleCard(
              title: 'PK is live',
              subtitle:
                  '${controller.localScore} - ${controller.opponentScore} against ${opponent.roomName}',
              buttonText: 'End PK',
              pending: controller.actionPending,
              onPressed: () => _run(controller.cancelOrEnd),
            )
          else ...[
            _DurationPicker(
              seconds: _durationSeconds,
              onChanged: (value) => setState(() => _durationSeconds = value),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: CircularProgressIndicator()),
              )
            else if ((_candidates ?? const <RoomPkRoomSummary>[]).isEmpty)
              _InfoCard(
                icon: Icons.groups_rounded,
                text: _error ??
                    'No public rooms are available for PK right now.',
                action: _error == null ? null : _loadCandidates,
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _candidates!.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final room = _candidates![index];
                    return _RoomCandidateTile(
                      room: room,
                      pending: controller.actionPending,
                      onTap: () => _run(
                        () => controller.challenge(
                          room,
                          durationSeconds: _durationSeconds,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
          if (surfacedError != null &&
              !((_candidates ?? const <RoomPkRoomSummary>[]).isEmpty &&
                  !controller.pending &&
                  !controller.active)) ...[
            const SizedBox(height: 10),
            Text(
              surfacedError,
              style: const TextStyle(
                color: RoomColors.coral,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DurationPicker extends StatelessWidget {
  const _DurationPicker({
    required this.seconds,
    required this.onChanged,
  });

  final int seconds;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Battle time',
          style: TextStyle(
            color: RoomColors.plum,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        for (final option in const <int>[120, 180, 300]) ...[
          ChoiceChip(
            label: Text('${option ~/ 60}m'),
            selected: seconds == option,
            onSelected: (_) => onChanged(option),
          ),
          if (option != 300) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _IncomingChallenge extends StatelessWidget {
  const _IncomingChallenge({
    required this.opponent,
    required this.pending,
    required this.onAccept,
    required this.onDecline,
  });

  final RoomPkRoomSummary opponent;
  final bool pending;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InfoCard(
          icon: Icons.flash_on_rounded,
          text: '${opponent.roomName} challenged this room to PK.',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: pending ? null : onDecline,
                child: const Text('Decline'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: pending ? null : onAccept,
                style: FilledButton.styleFrom(
                  backgroundColor: RoomColors.plum,
                ),
                child: const Text('Accept PK'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CurrentBattleCard extends StatelessWidget {
  const _CurrentBattleCard({
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.pending,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final String buttonText;
  final bool pending;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      icon: Icons.bolt_rounded,
      text: '$title\n$subtitle',
      action: pending ? null : onPressed,
      actionLabel: buttonText,
    );
  }
}

class _RoomCandidateTile extends StatelessWidget {
  const _RoomCandidateTile({
    required this.room,
    required this.pending,
    required this.onTap,
  });

  final RoomPkRoomSummary room;
  final bool pending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFAF7F1),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: pending ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: RoomColors.plum,
                backgroundImage: room.coverPhotoUrl == null
                    ? null
                    : NetworkImage(room.coverPhotoUrl!),
                child: room.coverPhotoUrl == null
                    ? Text(
                        room.roomName.isEmpty
                            ? '?'
                            : room.roomName.characters.first.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.roomName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: RoomColors.plum,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${room.onlineCount} online',
                      style: const TextStyle(
                        color: Color(0xFF7B6A86),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: RoomColors.plum,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.text,
    this.action,
    this.actionLabel = 'Retry',
  });

  final IconData icon;
  final String text;
  final VoidCallback? action;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFECE2D8)),
      ),
      child: Row(
        children: [
          Icon(icon, color: RoomColors.plum),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF554763),
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: action,
              child: Text(actionLabel),
            ),
        ],
      ),
    );
  }
}
