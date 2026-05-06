import 'dart:math' as math;

import 'package:flutter/material.dart';

class ProfileMatchScoreBadge extends StatefulWidget {
  const ProfileMatchScoreBadge({
    super.key,
    required this.score,
    this.compact = false,
  });

  final int score;
  final bool compact;

  @override
  State<ProfileMatchScoreBadge> createState() => _ProfileMatchScoreBadgeState();
}

class _ProfileMatchScoreBadgeState extends State<ProfileMatchScoreBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final score = widget.score.clamp(0, 100);
    final size = widget.compact ? 64.0 : 78.0;

    return Container(
      width: size,
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFCAD8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE84C72).withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              size: Size(widget.compact ? 34 : 42, widget.compact ? 31 : 38),
              painter: _HeartWavePainter(score: score, phase: _controller.value),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '$score%',
            style: TextStyle(
              color: const Color(0xFFE84C72),
              fontSize: widget.compact ? 13 : 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            'Match Score',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF7B6A86),
              fontSize: widget.compact ? 8.5 : 9.5,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeartWavePainter extends CustomPainter {
  const _HeartWavePainter({required this.score, required this.phase});

  final int score;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final heart = Path();
    final w = size.width;
    final h = size.height;

    heart
      ..moveTo(w / 2, h * 0.88)
      ..cubicTo(w * 0.06, h * 0.58, w * 0.02, h * 0.24, w * 0.26, h * 0.15)
      ..cubicTo(w * 0.42, h * 0.09, w * 0.50, h * 0.22, w / 2, h * 0.30)
      ..cubicTo(w * 0.50, h * 0.22, w * 0.58, h * 0.09, w * 0.74, h * 0.15)
      ..cubicTo(w * 0.98, h * 0.24, w * 0.94, h * 0.58, w / 2, h * 0.88)
      ..close();

    canvas.drawPath(heart, Paint()..color = const Color(0xFFFFE4EC));

    final fillTop = h * (1 - score / 100);
    final wave = Path()..moveTo(0, fillTop);
    for (var x = 0.0; x <= w; x += 2) {
      final y = fillTop + math.sin((x / w * math.pi * 2) + phase * math.pi * 2) * 2.5;
      wave.lineTo(x, y);
    }
    wave
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    canvas.save();
    canvas.clipPath(heart);
    canvas.drawPath(
      wave,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF6A93), Color(0xFFE84C72)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    canvas.restore();

    canvas.drawPath(
      heart,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = const Color(0xFFE84C72),
    );
  }

  @override
  bool shouldRepaint(covariant _HeartWavePainter oldDelegate) {
    return oldDelegate.score != score || oldDelegate.phase != phase;
  }
}
