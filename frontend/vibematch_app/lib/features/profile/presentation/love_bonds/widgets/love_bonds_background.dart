import 'package:flutter/material.dart';

class LoveBondsBackground extends StatelessWidget {
  const LoveBondsBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFCDEAFF),
            Color(0xFFF2D9FF),
            Color(0xFFFFCDE8),
          ],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: _LoveBondsSparkleLayer()),
          child,
        ],
      ),
    );
  }
}

class LoveBondsGlassPanel extends StatelessWidget {
  const LoveBondsGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 28,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF5AAA).withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _LoveBondsSparkleLayer extends StatelessWidget {
  const _LoveBondsSparkleLayer();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _LoveBondsSparklePainter());
  }
}

class _LoveBondsSparklePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final heartPaint = Paint()..color = Colors.white.withValues(alpha: 0.22);
    final pinkPaint = Paint()..color = const Color(0xFFFF7DBF).withValues(alpha: 0.18);
    final sparklePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.70)
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;

    final hearts = <Offset>[
      Offset(size.width * 0.12, size.height * 0.10),
      Offset(size.width * 0.84, size.height * 0.08),
      Offset(size.width * 0.18, size.height * 0.44),
      Offset(size.width * 0.74, size.height * 0.68),
      Offset(size.width * 0.30, size.height * 0.86),
    ];

    for (final point in hearts) {
      canvas.drawCircle(point, 14, heartPaint);
      canvas.drawCircle(point.translate(9, -7), 9, pinkPaint);
    }

    final sparkles = <Offset>[
      Offset(size.width * 0.22, size.height * 0.17),
      Offset(size.width * 0.65, size.height * 0.14),
      Offset(size.width * 0.91, size.height * 0.31),
      Offset(size.width * 0.10, size.height * 0.61),
      Offset(size.width * 0.47, size.height * 0.73),
      Offset(size.width * 0.82, size.height * 0.89),
    ];

    for (final point in sparkles) {
      canvas.drawLine(point.translate(-7, 0), point.translate(7, 0), sparklePaint);
      canvas.drawLine(point.translate(0, -7), point.translate(0, 7), sparklePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
