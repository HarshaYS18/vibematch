import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/room_pk_api_service.dart';
import '../../controllers/room_pk_controller.dart';
import '../room_theme.dart';

class LiveRoomPkOverlay extends StatelessWidget {
  const LiveRoomPkOverlay({
    super.key,
    required this.controller,
    required this.canManage,
  });

  final RoomPkController controller;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        switch (controller.phase) {
          case RoomPkPresentationPhase.incomingChallenge:
            if (!canManage) return const SizedBox.shrink();
            return _IncomingPkChallengeOverlay(controller: controller);
          case RoomPkPresentationPhase.intro:
            return _PkVsIntroOverlay(controller: controller);
          case RoomPkPresentationPhase.victory:
          case RoomPkPresentationPhase.defeat:
          case RoomPkPresentationPhase.draw:
            return _PkResultOverlay(controller: controller);
          case RoomPkPresentationPhase.idle:
          case RoomPkPresentationPhase.outgoingChallenge:
          case RoomPkPresentationPhase.live:
          case RoomPkPresentationPhase.settled:
            return const SizedBox.shrink();
        }
      },
    );
  }
}

class _IncomingPkChallengeOverlay extends StatelessWidget {
  const _IncomingPkChallengeOverlay({required this.controller});

  final RoomPkController controller;

  @override
  Widget build(BuildContext context) {
    final opponent = controller.opponentRoom;
    if (opponent == null) return const SizedBox.shrink();

    return Positioned(
      left: 14,
      right: 14,
      top: MediaQuery.paddingOf(context).top + 70,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: RoomColors.plum.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: RoomColors.coral.withValues(alpha: 0.7),
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x44000000),
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.flash_on_rounded,
                color: RoomColors.coral,
                size: 32,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PK challenge',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${opponent.roomName} wants to battle your room',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.76),
                        fontSize: 11.5,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: controller.actionPending
                    ? null
                    : () => unawaited(controller.decline()),
                child: const Text(
                  'No',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              FilledButton(
                onPressed: controller.actionPending
                    ? null
                    : () => unawaited(controller.accept()),
                style: FilledButton.styleFrom(
                  backgroundColor: RoomColors.coral,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Accept'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PkVsIntroOverlay extends StatelessWidget {
  const _PkVsIntroOverlay({required this.controller});

  final RoomPkController controller;

  @override
  Widget build(BuildContext context) {
    final local = controller.localRoom;
    final opponent = controller.opponentRoom;
    if (local == null || opponent == null) return const SizedBox.shrink();

    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final duration = reducedMotion
        ? Duration.zero
        : const Duration(milliseconds: 720);

    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(
          color: const Color(0xD9160E22),
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: duration,
              curve: Curves.easeOutBack,
              builder: (context, value, _) {
                final clamped = value.clamp(0.0, 1.0).toDouble();
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.translate(
                      offset: Offset(-110 * (1 - clamped), 0),
                      child: Opacity(
                        opacity: clamped,
                        child: _VsRoomCard(
                          room: local,
                          alignment: TextAlign.right,
                          accent: RoomColors.coral,
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(110 * (1 - clamped), 0),
                      child: Opacity(
                        opacity: clamped,
                        child: _VsRoomCard(
                          room: opponent,
                          alignment: TextAlign.left,
                          accent: RoomColors.aqua,
                        ),
                      ),
                    ),
                    Transform.scale(
                      scale: reducedMotion ? 1 : 0.7 + (0.3 * clamped),
                      child: Container(
                        width: 74,
                        height: 74,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: <Color>[
                              RoomColors.coral,
                              RoomColors.aqua,
                            ],
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: RoomColors.coral.withValues(
                                alpha: 0.28 * clamped,
                              ),
                              blurRadius: 32,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                        child: const Text(
                          'VS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: MediaQuery.sizeOf(context).height * 0.27,
                      child: Opacity(
                        opacity: clamped,
                        child: const Text(
                          'PK START',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            letterSpacing: 2.2,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _VsRoomCard extends StatelessWidget {
  const _VsRoomCard({
    required this.room,
    required this.alignment,
    required this.accent,
  });

  final RoomPkRoomSummary room;
  final TextAlign alignment;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment == TextAlign.right;
    return SizedBox(
      width: MediaQuery.sizeOf(context).width * 0.78,
      child: Align(
        alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width * 0.34,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: accent,
                backgroundImage: room.coverPhotoUrl == null
                    ? null
                    : NetworkImage(room.coverPhotoUrl!),
                child: room.coverPhotoUrl == null
                    ? Text(
                        room.roomName.isEmpty
                            ? '?'
                            : room.roomName
                                .characters
                                .first
                                .toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 9),
              Text(
                room.roomName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: alignment,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PkResultOverlay extends StatelessWidget {
  const _PkResultOverlay({required this.controller});

  final RoomPkController controller;

  @override
  Widget build(BuildContext context) {
    final phase = controller.phase;
    final victory = phase == RoomPkPresentationPhase.victory;
    final draw = phase == RoomPkPresentationPhase.draw;
    final reducedMotion = MediaQuery.of(context).disableAnimations;

    final title = victory
        ? 'VICTORY'
        : draw
            ? 'DRAW'
            : 'PK FINISHED';
    final subtitle = victory
        ? 'Your room won the battle!'
        : draw
            ? 'Both rooms finished level.'
            : '${controller.opponentRoom?.roomName ?? 'The other room'} won this round.';

    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(
          color: const Color(0xB8140D20),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: reducedMotion
                ? Duration.zero
                : const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              final progress = value.clamp(0.0, 1.0).toDouble();
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (victory && !reducedMotion)
                    CustomPaint(
                      painter: _PkConfettiPainter(progress),
                    ),
                  Center(
                    child: Transform.scale(
                      scale: reducedMotion ? 1 : 0.88 + (0.12 * progress),
                      child: Opacity(
                        opacity: progress,
                        child: Container(
                          width: math.min(
                            MediaQuery.sizeOf(context).width - 36,
                            340,
                          ),
                          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                          decoration: BoxDecoration(
                            color: RoomColors.plum.withValues(alpha: 0.97),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: victory
                                  ? const Color(0xFFFFD76A)
                                  : Colors.white.withValues(alpha: 0.18),
                            ),
                            boxShadow: const <BoxShadow>[
                              BoxShadow(
                                color: Color(0x55000000),
                                blurRadius: 30,
                                offset: Offset(0, 14),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                victory
                                    ? Icons.emoji_events_rounded
                                    : draw
                                        ? Icons.handshake_rounded
                                        : Icons.favorite_rounded,
                                color: victory
                                    ? const Color(0xFFFFD76A)
                                    : RoomColors.aqua,
                                size: victory ? 58 : 46,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                title,
                                style: TextStyle(
                                  color: victory
                                      ? const Color(0xFFFFD76A)
                                      : Colors.white,
                                  fontSize: 25,
                                  letterSpacing: victory ? 2.1 : 0.8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                subtitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 12,
                                  height: 1.3,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                '${controller.localScore}  :  ${controller.opponentScore}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PkConfettiPainter extends CustomPainter {
  const _PkConfettiPainter(this.progress);

  final double progress;

  static const _colors = <Color>[
    Color(0xFFFFD76A),
    RoomColors.coral,
    RoomColors.aqua,
    Color(0xFF8C5CF6),
    Colors.white,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (var index = 0; index < 42; index++) {
      final xSeed = ((index * 37) % 101) / 100;
      final ySeed = ((index * 19) % 67) / 67;
      final drift = math.sin(index * 1.7 + progress * math.pi * 2) * 22;
      final x = (xSeed * size.width + drift)
          .clamp(0.0, size.width)
          .toDouble();
      final y = -20 + ((size.height + 80) * ((progress + ySeed) % 1));
      final paint = Paint()
        ..color = _colors[index % _colors.length].withValues(
          alpha: 0.55 + ((index % 4) * 0.1),
        );
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate((index * 0.48) + progress * math.pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: 5 + (index % 4) * 2,
            height: 10 + (index % 3) * 3,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PkConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
