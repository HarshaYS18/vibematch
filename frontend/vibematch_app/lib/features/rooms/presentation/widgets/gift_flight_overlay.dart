import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'gift_modules/gift_visual.dart';

class GiftFlightEvent {
  const GiftFlightEvent({
    required this.id,
    required this.gift,
    required this.senderName,
    required this.receiverName,
    required this.combo,
    this.multiplier,
    this.rewardCoinAmount,
    this.startAlignment = Alignment.center,
    this.endAlignment = const Alignment(0.68, -0.16),
  });

  final String id;
  final GiftItem gift;
  final String senderName;
  final String receiverName;
  final int combo;
  final int? multiplier;
  final int? rewardCoinAmount;
  final Alignment startAlignment;
  final Alignment endAlignment;

  bool get isLuckyWin => multiplier != null && multiplier! > 1;
  bool get isBigWin => (multiplier ?? 0) >= 100;
  bool get isMegaWin => (multiplier ?? 0) >= 500;
  bool get isLegendWin => (multiplier ?? 0) >= 1000;
}

class GiftFlightOverlay extends StatelessWidget {
  const GiftFlightOverlay({super.key, required this.event, required this.onCompleted});

  final GiftFlightEvent? event;
  final VoidCallback onCompleted;

  @override
  Widget build(BuildContext context) {
    final current = event;
    if (current == null) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: _GiftFlightActor(key: ValueKey(current.id), event: current, onCompleted: onCompleted),
      ),
    );
  }
}

class _GiftFlightActor extends StatefulWidget {
  const _GiftFlightActor({super.key, required this.event, required this.onCompleted});

  final GiftFlightEvent event;
  final VoidCallback onCompleted;

  @override
  State<_GiftFlightActor> createState() => _GiftFlightActorState();
}

class _GiftFlightActorState extends State<_GiftFlightActor> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1180));
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
    _controller
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          Future<void>.delayed(const Duration(milliseconds: 180), () {
            if (mounted) widget.onCompleted();
          });
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Offset _alignmentToOffset(Size size, Alignment alignment) {
    return Offset((alignment.x + 1) * size.width / 2, (alignment.y + 1) * size.height / 2);
  }

  Offset _bezier(Offset p0, Offset p1, Offset p2, double t) {
    final oneMinusT = 1 - t;
    return Offset(
      oneMinusT * oneMinusT * p0.dx + 2 * oneMinusT * t * p1.dx + t * t * p2.dx,
      oneMinusT * oneMinusT * p0.dy + 2 * oneMinusT * t * p1.dy + t * t * p2.dy,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final start = _alignmentToOffset(size, widget.event.startAlignment);
        final end = _alignmentToOffset(size, widget.event.endAlignment);
        final control = Offset(
          (start.dx + end.dx) / 2,
          math.min(start.dy, end.dy) - size.height * 0.18,
        );

        return AnimatedBuilder(
          animation: _curve,
          builder: (context, child) {
            final t = _curve.value;
            final position = _bezier(start, control, end, t);
            final scale = t < 0.72 ? 0.48 + (t * 0.54) : 1.02 - ((t - 0.72) * 0.22);
            final opacity = t < 0.90 ? 1.0 : (1 - ((t - 0.90) / 0.10)).clamp(0.0, 1.0);
            final rotation = math.sin(t * math.pi * 2) * 0.10;
            final pop = t > 0.72 ? ((t - 0.72) / 0.28).clamp(0.0, 1.0) : 0.0;

            return Stack(
              children: [
                Positioned(
                  left: position.dx - 34,
                  top: position.dy - 34,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.rotate(
                      angle: rotation,
                      child: Transform.scale(scale: scale, child: _FlyingGiftVisual(event: widget.event)),
                    ),
                  ),
                ),
                if (pop > 0)
                  Positioned(
                    left: end.dx - 58,
                    top: end.dy - 58,
                    child: Opacity(
                      opacity: (1 - pop).clamp(0.0, 1.0),
                      child: _GiftLandingBurst(event: widget.event, progress: pop),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _FlyingGiftVisual extends StatelessWidget {
  const _FlyingGiftVisual({required this.event});

  final GiftFlightEvent event;

  @override
  Widget build(BuildContext context) {
    final glow = GiftWinStyle.fromMultiplier(event.multiplier).colors;
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: glow.first.withValues(alpha: 0.42), blurRadius: 26, spreadRadius: 2),
          BoxShadow(color: glow.last.withValues(alpha: 0.25), blurRadius: 34, spreadRadius: 1),
        ],
      ),
      child: GiftVisual(
        icon: event.gift.icon,
        colors: event.gift.colors,
        assetPath: event.gift.assetPath,
        assetUrl: event.gift.assetUrl,
        size: 68,
        padding: 0,
      ),
    );
  }
}

class _GiftLandingBurst extends StatelessWidget {
  const _GiftLandingBurst({required this.event, required this.progress});

  final GiftFlightEvent event;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = GiftWinStyle.fromMultiplier(event.multiplier).colors;
    return SizedBox(
      width: 116,
      height: 116,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 28 + progress * 80,
            height: 28 + progress * 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colors.first.withValues(alpha: 0.70), width: 2.0),
              boxShadow: [BoxShadow(color: colors.first.withValues(alpha: 0.28), blurRadius: 22, spreadRadius: 6)],
            ),
          ),
          for (var i = 0; i < 8; i++)
            Transform.translate(
              offset: Offset(math.cos(i * math.pi / 4) * progress * 42, math.sin(i * math.pi / 4) * progress * 42),
              child: Icon(Icons.auto_awesome_rounded, color: i.isEven ? colors.first : colors.last, size: 9 + (i % 3) * 3),
            ),
        ],
      ),
    );
  }
}

class GiftWinStyle {
  const GiftWinStyle({required this.colors, required this.label});

  final List<Color> colors;
  final String label;

  static GiftWinStyle fromMultiplier(int? multiplier) {
    final value = multiplier ?? 0;
    if (value >= 1000) return const GiftWinStyle(label: 'LEGEND', colors: [Color(0xFF8B5CF6), Color(0xFF22D3EE)]);
    if (value >= 500) return const GiftWinStyle(label: 'MEGA', colors: [Color(0xFFFF2D95), Color(0xFF00E5FF)]);
    if (value >= 100) return const GiftWinStyle(label: 'SUPER', colors: [Color(0xFFFFD166), Color(0xFFFF8A00)]);
    if (value > 1) return const GiftWinStyle(label: 'WIN', colors: [Color(0xFF12C7B7), Color(0xFF6D5DF6)]);
    return const GiftWinStyle(label: 'GIFT', colors: [Color(0xFFFFD166), Color(0xFFE84C72)]);
  }
}