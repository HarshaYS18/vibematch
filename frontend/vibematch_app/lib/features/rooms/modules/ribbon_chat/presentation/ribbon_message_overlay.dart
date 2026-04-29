import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/ribbon_background_style.dart';
import '../models/ribbon_message.dart';

class RibbonMessageOverlay extends StatefulWidget {
  final List<RibbonMessage> messages;
  final VoidCallback? onQueueFinished;

  const RibbonMessageOverlay({
    super.key,
    required this.messages,
    this.onQueueFinished,
  });

  @override
  State<RibbonMessageOverlay> createState() => _RibbonMessageOverlayState();
}

class _RibbonMessageOverlayState extends State<RibbonMessageOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _shineAnimation;
  late Animation<double> _pulseAnimation;

  final List<RibbonMessage> _queue = <RibbonMessage>[];

  RibbonMessage? _activeMessage;
  Timer? _gapTimer;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    );

    _configureAnimations();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _playNext();
      }
    });

    _queue.addAll(widget.messages);
    _playNext();
  }

  @override
  void didUpdateWidget(covariant RibbonMessageOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldIds = oldWidget.messages.map((message) => message.id).toSet();
    final newMessages = widget.messages
        .where((message) => !oldIds.contains(message.id))
        .toList();

    if (newMessages.isNotEmpty) {
      _queue.addAll(newMessages);
      if (!_isPlaying) _playNext();
    }
  }

  void _configureAnimations() {
    _slideAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(1.35, 0),
          end: const Offset(0.04, 0),
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 28,
      ),
      TweenSequenceItem(
        tween: ConstantTween<Offset>(const Offset(0.04, 0)),
        weight: 42,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(0.04, 0),
          end: const Offset(-1.35, 0),
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 30,
      ),
    ]).animate(_controller);

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0, end: 1), weight: 15),
      TweenSequenceItem(tween: ConstantTween<double>(1), weight: 70),
      TweenSequenceItem(tween: Tween<double>(begin: 1, end: 0), weight: 15),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _shineAnimation = Tween<double>(begin: -1.2, end: 1.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );

    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.96, end: 1.02)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.02, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 18,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 64),
    ]).animate(_controller);
  }

  void _playNext() {
    _gapTimer?.cancel();

    if (_queue.isEmpty) {
      setState(() {
        _activeMessage = null;
        _isPlaying = false;
      });
      widget.onQueueFinished?.call();
      return;
    }

    final next = _queue.removeAt(0);

    setState(() {
      _activeMessage = next;
      _isPlaying = true;
    });

    _controller.duration = next.duration;
    _controller.reset();

    _gapTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _gapTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeMessage = _activeMessage;
    if (activeMessage == null) return const SizedBox.shrink();

    final style = RibbonBackgroundStyle.fromType(activeMessage.backgroundType);

    return IgnorePointer(
      ignoring: true,
      child: Positioned(
        top: 96,
        left: 0,
        right: 0,
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: _RibbonMessageCard(
                      message: activeMessage,
                      style: style,
                      shinePosition: _shineAnimation.value,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RibbonMessageCard extends StatelessWidget {
  final RibbonMessage message;
  final RibbonBackgroundStyle style;
  final double shinePosition;

  const _RibbonMessageCard({
    required this.message,
    required this.style,
    required this.shinePosition,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = min(screenWidth * 0.92, 430.0);

    return SizedBox(
      width: cardWidth,
      height: 60,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _RibbonBackgroundPainter(style: style)),
          ),
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: CustomPaint(painter: _RibbonPatternPainter(style: style)),
            ),
          ),
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: CustomPaint(
                painter: _RibbonShinePainter(
                  style: style,
                  shinePosition: shinePosition,
                ),
              ),
            ),
          ),
          Positioned(
            left: -3,
            top: -6,
            bottom: -6,
            child: Container(
              width: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    style.iconOuterStart,
                    style.iconOuterMiddle,
                    style.iconOuterEnd,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: style.glowColor.withValues(alpha: 0.45),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 53,
                  height: 53,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [style.iconInnerStart, style.iconInnerEnd],
                    ),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Icon(style.badgeIcon, color: style.coinTextColor, size: 27),
                ),
              ),
            ),
          ),
          Positioned(
            left: 78,
            right: 22,
            top: 8,
            bottom: 8,
            child: Row(
              children: [
                Expanded(
                  child: RichText(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: message.senderName,
                          style: TextStyle(
                            color: style.primaryTextColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.1,
                          ),
                        ),
                        TextSpan(
                          text: ' sent a floating vibe ',
                          style: TextStyle(
                            color: style.secondaryTextColor.withValues(alpha: 0.92),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: message.text,
                          style: TextStyle(
                            color: style.secondaryTextColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.05,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: const Color(0xFF12081E).withValues(alpha: 0.58),
                    border: Border.all(color: style.coinTextColor.withValues(alpha: 0.45)),
                    boxShadow: [
                      BoxShadow(color: style.glowColor.withValues(alpha: 0.22), blurRadius: 10),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.monetization_on_rounded, color: style.coinTextColor, size: 14),
                      const SizedBox(width: 3),
                      Text(
                        '${message.coinCost}',
                        style: TextStyle(
                          color: style.coinTextColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
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

class _RibbonBackgroundPainter extends CustomPainter {
  final RibbonBackgroundStyle style;

  const _RibbonBackgroundPainter({required this.style});

  @override
  void paint(Canvas canvas, Size size) {
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(20, 4, size.width - 40, size.height - 8),
      const Radius.circular(999),
    );

    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: style.bodyColors,
        stops: const [0.0, 0.35, 0.68, 1.0],
      ).createShader(bodyRect.outerRect);

    canvas.drawRRect(bodyRect, bodyPaint);

    final glowPaint = Paint()
      ..color = style.glowColor.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);

    canvas.drawRRect(bodyRect, glowPaint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..shader = LinearGradient(colors: style.borderColors).createShader(bodyRect.outerRect);

    canvas.drawRRect(bodyRect, borderPaint);

    final leftFold = Path()
      ..moveTo(20, 10)
      ..lineTo(0, size.height / 2)
      ..lineTo(20, size.height - 10)
      ..close();

    final rightFold = Path()
      ..moveTo(size.width - 20, 10)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width - 20, size.height - 10)
      ..close();

    final foldPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: style.foldColors,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(leftFold, foldPaint);
    canvas.drawPath(rightFold, foldPaint);
  }

  @override
  bool shouldRepaint(covariant _RibbonBackgroundPainter oldDelegate) => oldDelegate.style != style;
}

class _RibbonPatternPainter extends CustomPainter {
  final RibbonBackgroundStyle style;

  const _RibbonPatternPainter({required this.style});

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.055)
      ..style = PaintingStyle.fill;

    for (double x = 96; x < size.width - 28; x += 28) {
      canvas.drawCircle(Offset(x, 16), 1.25, dotPaint);
      canvas.drawCircle(Offset(x + 13, size.height - 16), 1.0, dotPaint);
    }

    final linePaint = Paint()
      ..color = style.primaryTextColor.withValues(alpha: 0.08)
      ..strokeWidth = 1.0;

    for (double x = 112; x < size.width - 40; x += 44) {
      canvas.drawLine(Offset(x, 9), Offset(x + 22, size.height - 9), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RibbonPatternPainter oldDelegate) => oldDelegate.style != style;
}

class _RibbonShinePainter extends CustomPainter {
  final RibbonBackgroundStyle style;
  final double shinePosition;

  const _RibbonShinePainter({required this.style, required this.shinePosition});

  @override
  void paint(Canvas canvas, Size size) {
    final shineWidth = size.width * 0.18;
    final x = size.width * shinePosition;
    final shineRect = Rect.fromLTWH(x, 0, shineWidth, size.height);

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.42),
          style.primaryTextColor.withValues(alpha: 0.22),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(shineRect)
      ..blendMode = BlendMode.plus;

    canvas.save();
    canvas.translate(x + shineWidth / 2, size.height / 2);
    canvas.rotate(-0.35);
    canvas.translate(-(x + shineWidth / 2), -size.height / 2);
    canvas.drawRect(shineRect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RibbonShinePainter oldDelegate) {
    return oldDelegate.shinePosition != shinePosition || oldDelegate.style != style;
  }
}
