import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../realtime/app_realtime_hub.dart';
import '../../data/active_room_context.dart';
import '../../data/live_room_system_event_bus.dart';

class LuckyWinCelebrationOverlay extends StatefulWidget {
  const LuckyWinCelebrationOverlay({super.key});

  @override
  State<LuckyWinCelebrationOverlay> createState() =>
      _LuckyWinCelebrationOverlayState();
}

class _LuckyWinCelebrationOverlayState
    extends State<LuckyWinCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  static const int _maxSeenEvents = 256;
  static const int _maxQueuedEvents = 8;

  final Queue<_LuckyWinPresentation> _queue = Queue<_LuckyWinPresentation>();
  final Set<String> _seenEventIds = <String>{};
  final Queue<String> _seenEventOrder = Queue<String>();

  late final AnimationController _controller;
  _LuckyWinPresentation? _active;
  StreamSubscription<dynamic>? _roomEventSubscription;
  Timer? _nextTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _LuckyWinTier.big.duration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _finishActive();
      });
    _roomEventSubscription = AppRealtimeHub.shared.events.listen((envelope) {
      final event = decodeLiveRoomSystemEvent(
        envelope,
        roomId: ActiveRoomContext.roomPublicId,
      );
      if (event != null) _handleRoomEvent(event);
    });
    unawaited(AppRealtimeHub.shared.start());
  }

  @override
  void dispose() {
    unawaited(_roomEventSubscription?.cancel());
    _nextTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _handleRoomEvent(LiveRoomSystemEvent event) {
    if (!event.isRoomGiftSent || !event.isLuckyGift) return;

    final tier = _LuckyWinTier.fromMultiplier(event.luckyMultiplier);
    if (tier == null || !_rememberEvent(event.id)) return;

    final presentation = _LuckyWinPresentation(
      senderName: event.actorName.trim().isEmpty
          ? 'Vibe User'
          : event.actorName.trim(),
      receiverName: event.targetName.trim().isEmpty
          ? 'Vibe User'
          : event.targetName.trim(),
      giftName: event.giftName.trim().isEmpty ? 'Lucky Gift' : event.giftName.trim(),
      multiplier: event.luckyMultiplier,
      rewardCoins: event.luckyRewardCoinAmount,
      tier: tier,
    );

    final active = _active;
    if (active == null || presentation.tier.rank > active.tier.rank) {
      _start(presentation);
      return;
    }

    if (_queue.length >= _maxQueuedEvents) _queue.removeFirst();
    _queue.addLast(presentation);
  }

  bool _rememberEvent(String id) {
    final cleanId = id.trim();
    if (cleanId.isEmpty) return true;
    if (!_seenEventIds.add(cleanId)) return false;
    _seenEventOrder.addLast(cleanId);
    while (_seenEventOrder.length > _maxSeenEvents) {
      _seenEventIds.remove(_seenEventOrder.removeFirst());
    }
    return true;
  }

  void _start(_LuckyWinPresentation presentation) {
    _nextTimer?.cancel();
    _controller
      ..stop()
      ..duration = presentation.tier.duration
      ..reset();
    setState(() => _active = presentation);
    _controller.forward();
  }

  void _finishActive() {
    if (!mounted || _active == null) return;
    setState(() => _active = null);
    if (_queue.isEmpty) return;
    _nextTimer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted || _active != null || _queue.isEmpty) return;
      _start(_queue.removeFirst());
    });
  }

  @override
  Widget build(BuildContext context) {
    final presentation = _active;
    if (presentation == null) return const SizedBox.shrink();

    return Positioned.fill(
      key: const ValueKey('lucky-win-celebration'),
      child: IgnorePointer(
        child: RepaintBoundary(
          child: Semantics(
            liveRegion: true,
            label:
                '${presentation.tier.title} x${presentation.multiplier}. '
                '${presentation.senderName} sent ${presentation.giftName} to '
                '${presentation.receiverName}.',
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => _LuckyWinScene(
                presentation: presentation,
                progress: _controller.value,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LuckyWinScene extends StatelessWidget {
  const _LuckyWinScene({
    required this.presentation,
    required this.progress,
  });

  final _LuckyWinPresentation presentation;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final tier = presentation.tier;
    final enter = Curves.easeOutBack.transform(_phase(progress, 0, 0.20));
    final exit = 1 - Curves.easeInCubic.transform(_phase(progress, 0.86, 1));
    final visibility = math.min(enter, exit).clamp(0.0, 1.0).toDouble();
    final impact = 1 - Curves.easeOut.transform(_phase(progress, 0, 0.34));
    final shakeX = math.sin(progress * math.pi * tier.shakeCycles) *
        tier.shakePixels *
        impact;
    final shakeY = math.cos(progress * math.pi * (tier.shakeCycles + 2)) *
        tier.shakePixels *
        0.42 *
        impact;
    final heartbeat =
        1 + math.sin(progress * math.pi * tier.pulseCycles) * tier.pulseScale;
    final heroScale = (0.58 + enter * 0.42) * heartbeat;
    final flash = (1 - _phase(progress, 0, 0.18)) * tier.flashOpacity;

    return Opacity(
      opacity: visibility,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 0.92,
                colors: [
                  tier.colors.first.withValues(
                    alpha: tier.backdropOpacity * visibility,
                  ),
                  tier.colors.last.withValues(
                    alpha: tier.backdropOpacity * 0.42 * visibility,
                  ),
                  Colors.black.withValues(
                    alpha: tier.darkBackdropOpacity * visibility,
                  ),
                  Colors.transparent,
                ],
                stops: const [0, 0.28, 0.70, 1],
              ),
            ),
          ),
          CustomPaint(
            painter: _LuckyEffectsPainter(
              progress: progress,
              tier: tier,
              opacity: visibility,
            ),
          ),
          Center(
            child: Transform.translate(
              offset: Offset(shakeX, shakeY),
              child: Transform.scale(
                scale: heroScale,
                child: _LuckyWinHero(presentation: presentation),
              ),
            ),
          ),
          if (flash > 0)
            ColoredBox(color: Colors.white.withValues(alpha: flash)),
        ],
      ),
    );
  }
}

class _LuckyWinHero extends StatelessWidget {
  const _LuckyWinHero({required this.presentation});

  final _LuckyWinPresentation presentation;

  @override
  Widget build(BuildContext context) {
    final tier = presentation.tier;
    final width = math.min(MediaQuery.sizeOf(context).width * 0.88, 430.0);
    return SizedBox(
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            top: -44,
            child: Icon(
              tier.icon,
              size: tier == _LuckyWinTier.jackpot ? 64 : 50,
              color: tier.colors.first,
              shadows: [
                Shadow(
                  color: tier.colors.first.withValues(alpha: 0.92),
                  blurRadius: 24,
                ),
                const Shadow(color: Colors.white, blurRadius: 9),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.black.withValues(alpha: 0.90),
                  tier.colors.last.withValues(alpha: 0.86),
                  tier.colors.first.withValues(alpha: 0.76),
                  Colors.black.withValues(alpha: 0.92),
                ],
              ),
              border: Border.all(
                color: tier.colors.first.withValues(alpha: 0.92),
                width: tier == _LuckyWinTier.jackpot ? 2.4 : 1.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: tier.colors.first.withValues(alpha: 0.62),
                  blurRadius: tier == _LuckyWinTier.jackpot ? 58 : 38,
                  spreadRadius: tier == _LuckyWinTier.jackpot ? 10 : 5,
                ),
                BoxShadow(
                  color: tier.colors.last.withValues(alpha: 0.46),
                  blurRadius: 72,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tier.title,
                  key: const ValueKey('lucky-win-title'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: tier == _LuckyWinTier.jackpot ? 27 : 22,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: tier == _LuckyWinTier.jackpot ? 2.4 : 1.6,
                    decoration: TextDecoration.none,
                    shadows: [
                      Shadow(color: tier.colors.first, blurRadius: 16),
                      Shadow(color: tier.colors.last, blurRadius: 28),
                    ],
                  ),
                ),
                const SizedBox(height: 7),
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      Colors.white,
                      tier.colors.first,
                      Colors.white,
                      tier.colors.last,
                    ],
                  ).createShader(bounds),
                  child: Text(
                    'x${presentation.multiplier}',
                    key: const ValueKey('lucky-win-multiplier'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: tier == _LuckyWinTier.jackpot ? 64 : 54,
                      fontWeight: FontWeight.w900,
                      height: 0.94,
                      letterSpacing: -2,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  presentation.giftName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(child: _NameText(presentation.senderName)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.double_arrow_rounded,
                        color: tier.colors.first,
                        size: 18,
                      ),
                    ),
                    Flexible(child: _NameText(presentation.receiverName)),
                  ],
                ),
                if (presentation.rewardCoins > 0) ...[
                  const SizedBox(height: 13),
                  Container(
                    key: const ValueKey('lucky-win-reward'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.30),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: tier.colors.first.withValues(alpha: 0.72),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.toll_rounded,
                          color: tier.colors.first,
                          size: 17,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '+${_compactCoins(presentation.rewardCoins)} COINS',
                          style: TextStyle(
                            color: tier.colors.first,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (tier == _LuckyWinTier.jackpot) ...[
            Positioned(
              left: -14,
              top: 30,
              child: _CornerBolt(color: tier.colors.first, turns: -0.08),
            ),
            Positioned(
              right: -14,
              top: 30,
              child: _CornerBolt(color: tier.colors.last, turns: 0.08),
            ),
          ],
        ],
      ),
    );
  }
}

class _NameText extends StatelessWidget {
  const _NameText(this.value);
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.84),
        fontSize: 12,
        fontWeight: FontWeight.w800,
        decoration: TextDecoration.none,
      ),
    );
  }
}

class _CornerBolt extends StatelessWidget {
  const _CornerBolt({required this.color, required this.turns});
  final Color color;
  final double turns;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: turns * math.pi * 2,
      child: Icon(
        Icons.bolt_rounded,
        size: 54,
        color: color,
        shadows: [Shadow(color: color, blurRadius: 22)],
      ),
    );
  }
}

class _LuckyEffectsPainter extends CustomPainter {
  const _LuckyEffectsPainter({
    required this.progress,
    required this.tier,
    required this.opacity,
  });

  final double progress;
  final _LuckyWinTier tier;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final shortest = math.min(size.width, size.height);
    final fill = Paint()..style = PaintingStyle.fill;

    // Rotating rays create the large jackpot halo without dozens of widgets.
    final rayCount = tier == _LuckyWinTier.jackpot ? 24 : 16;
    final rotation = progress * math.pi *
        (tier == _LuckyWinTier.jackpot ? 1.8 : 1.0);
    for (var i = 0; i < rayCount; i++) {
      final angle = rotation + math.pi * 2 * i / rayCount;
      final inner = shortest * 0.15;
      final outer = shortest *
          (tier == _LuckyWinTier.jackpot ? 0.68 : 0.56);
      final width = i.isEven ? 0.025 : 0.014;
      final p1 = center + Offset(math.cos(angle), math.sin(angle)) * inner;
      final p2 = center +
          Offset(math.cos(angle - width), math.sin(angle - width)) * outer;
      final p3 = center +
          Offset(math.cos(angle + width), math.sin(angle + width)) * outer;
      fill.color = tier.colors[i % tier.colors.length].withValues(
        alpha: opacity * (i.isEven ? 0.13 : 0.07),
      );
      canvas.drawPath(
        Path()
          ..moveTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy)
          ..lineTo(p3.dx, p3.dy)
          ..close(),
        fill,
      );
    }

    // Expanding shockwave rings make each tier land with a visible impact.
    for (var i = 0; i < tier.ringCount; i++) {
      final delayed = _phase(
        progress,
        i * 0.07,
        math.min(1.0, 0.58 + i * 0.07),
      );
      if (delayed <= 0 || delayed >= 1) continue;
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 + (1 - delayed) * 3.5
        ..color = tier.colors[i % tier.colors.length].withValues(
          alpha: (1 - delayed) * opacity * 0.74,
        );
      canvas.drawCircle(
        center,
        shortest * (0.10 + delayed * 0.56),
        ringPaint,
      );
    }

    // Deterministic particles keep animation repeatable and cheap to repaint.
    for (var i = 0; i < tier.particleCount; i++) {
      final delay = (i % 9) * 0.018;
      final local = _phase(
        progress,
        delay,
        math.min(1.0, 0.76 + delay),
      );
      if (local <= 0 || local >= 1) continue;

      final angle = i * 2.399963229728653 +
          math.sin(i * 0.71) * 0.28 +
          progress * (i.isEven ? 0.34 : -0.22);
      final speed = 0.26 + (i % 7) / 7 * 0.48;
      final distance = shortest * speed * Curves.easeOutCubic.transform(local);
      final arc = math.sin(local * math.pi) * shortest * 0.07 *
          (i.isEven ? -1 : 1);
      final position = center +
          Offset(math.cos(angle), math.sin(angle)) * distance +
          Offset(0, arc + local * local * shortest * 0.08);
      final fade = math.sin(local * math.pi).clamp(0.0, 1.0).toDouble();
      final radius = 2.0 + (i % 4) * 1.35;
      fill.color = tier.colors[i % tier.colors.length].withValues(
        alpha: opacity * fade * 0.94,
      );

      if (i % 5 == 0) {
        canvas.save();
        canvas.translate(position.dx, position.dy);
        canvas.rotate(angle + progress * math.pi * 4);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: radius * 1.45,
              height: radius * 3.8,
            ),
            const Radius.circular(2),
          ),
          fill,
        );
        canvas.restore();
      } else {
        canvas.drawCircle(position, radius, fill);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LuckyEffectsPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.opacity != opacity;
}

enum _LuckyWinTier {
  big(
    multiplier: 100,
    rank: 1,
    title: 'BIG WIN',
    duration: Duration(milliseconds: 2400),
    colors: <Color>[Color(0xFFFFE082), Color(0xFFFF8A00)],
    icon: Icons.auto_awesome_rounded,
    particleCount: 34,
    ringCount: 2,
    shakePixels: 3.5,
    shakeCycles: 10,
    pulseCycles: 7,
    pulseScale: 0.018,
    backdropOpacity: 0.25,
    darkBackdropOpacity: 0.08,
    flashOpacity: 0.16,
  ),
  mega(
    multiplier: 500,
    rank: 2,
    title: 'MEGA WIN',
    duration: Duration(milliseconds: 3200),
    colors: <Color>[Color(0xFFFFD166), Color(0xFFFF2D95), Color(0xFF00E5FF)],
    icon: Icons.local_fire_department_rounded,
    particleCount: 60,
    ringCount: 4,
    shakePixels: 7.0,
    shakeCycles: 16,
    pulseCycles: 10,
    pulseScale: 0.028,
    backdropOpacity: 0.34,
    darkBackdropOpacity: 0.16,
    flashOpacity: 0.24,
  ),
  jackpot(
    multiplier: 1000,
    rank: 3,
    title: 'JACKPOT',
    duration: Duration(milliseconds: 4200),
    colors: <Color>[
      Color(0xFFFFE66D),
      Color(0xFFFF2D95),
      Color(0xFF22D3EE),
      Color(0xFF8B5CF6),
    ],
    icon: Icons.workspace_premium_rounded,
    particleCount: 92,
    ringCount: 6,
    shakePixels: 11.0,
    shakeCycles: 24,
    pulseCycles: 14,
    pulseScale: 0.038,
    backdropOpacity: 0.44,
    darkBackdropOpacity: 0.30,
    flashOpacity: 0.34,
  );

  const _LuckyWinTier({
    required this.multiplier,
    required this.rank,
    required this.title,
    required this.duration,
    required this.colors,
    required this.icon,
    required this.particleCount,
    required this.ringCount,
    required this.shakePixels,
    required this.shakeCycles,
    required this.pulseCycles,
    required this.pulseScale,
    required this.backdropOpacity,
    required this.darkBackdropOpacity,
    required this.flashOpacity,
  });

  final int multiplier;
  final int rank;
  final String title;
  final Duration duration;
  final List<Color> colors;
  final IconData icon;
  final int particleCount;
  final int ringCount;
  final double shakePixels;
  final int shakeCycles;
  final int pulseCycles;
  final double pulseScale;
  final double backdropOpacity;
  final double darkBackdropOpacity;
  final double flashOpacity;

  static _LuckyWinTier? fromMultiplier(int multiplier) {
    for (final tier in values) {
      if (tier.multiplier == multiplier) return tier;
    }
    return null;
  }
}

class _LuckyWinPresentation {
  const _LuckyWinPresentation({
    required this.senderName,
    required this.receiverName,
    required this.giftName,
    required this.multiplier,
    required this.rewardCoins,
    required this.tier,
  });

  final String senderName;
  final String receiverName;
  final String giftName;
  final int multiplier;
  final int rewardCoins;
  final _LuckyWinTier tier;
}

double _phase(double value, double start, double end) {
  if (end <= start) return value >= end ? 1 : 0;
  return ((value - start) / (end - start)).clamp(0.0, 1.0).toDouble();
}

String _compactCoins(int value) {
  if (value >= 1000000) {
    final digits = value >= 10000000 ? 0 : 1;
    return '${(value / 1000000).toStringAsFixed(digits)}M';
  }
  if (value >= 1000) {
    final digits = value >= 10000 ? 0 : 1;
    return '${(value / 1000).toStringAsFixed(digits)}K';
  }
  return '$value';
}
