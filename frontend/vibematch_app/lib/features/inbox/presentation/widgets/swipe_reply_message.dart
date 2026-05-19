import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SwipeReplyMessage extends StatefulWidget {
  const SwipeReplyMessage({
    super.key,
    required this.isMine,
    required this.onReply,
    required this.child,
    this.threshold = 58,
    this.maxDrag = 86,
  });

  final bool isMine;
  final VoidCallback onReply;
  final Widget child;
  final double threshold;
  final double maxDrag;

  @override
  State<SwipeReplyMessage> createState() => _SwipeReplyMessageState();
}

class _SwipeReplyMessageState extends State<SwipeReplyMessage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  double _dragOffset = 0;
  bool _thresholdBuzzed = false;

  double get _direction => widget.isMine ? -1 : 1;
  bool get _passedThreshold => _dragOffset.abs() >= widget.threshold;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 210),
    )..addListener(() {
        setState(() => _dragOffset = _animation.value);
      });
    _animation = const AlwaysStoppedAnimation<double>(0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final delta = details.delta.dx;
    if (delta.sign != _direction.sign && _dragOffset.abs() < 4) return;
    final next = (_dragOffset + delta).clamp(-widget.maxDrag, widget.maxDrag);
    if (next.sign != _direction.sign) {
      setState(() => _dragOffset = 0);
      return;
    }
    setState(() => _dragOffset = next.toDouble());
    if (_passedThreshold && !_thresholdBuzzed) {
      _thresholdBuzzed = true;
      HapticFeedback.selectionClick();
    } else if (!_passedThreshold) {
      _thresholdBuzzed = false;
    }
  }

  void _handleDragEnd([DragEndDetails? _]) {
    final shouldReply = _passedThreshold;
    if (shouldReply) widget.onReply();
    _animateBack();
  }

  void _animateBack() {
    _animation = Tween<double>(begin: _dragOffset, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller
      ..reset()
      ..forward();
    _thresholdBuzzed = false;
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dragOffset.abs() / widget.threshold).clamp(0.0, 1.0);
    final iconAlignment = widget.isMine ? Alignment.centerRight : Alignment.centerLeft;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      onHorizontalDragCancel: _animateBack,
      child: Stack(
        alignment: iconAlignment,
        children: [
          Positioned.fill(
            child: Align(
              alignment: iconAlignment,
              child: Transform.scale(
                scale: 0.82 + math.min(progress, 1) * 0.18,
                child: Opacity(
                  opacity: progress,
                  child: Container(
                    width: 34,
                    height: 34,
                    margin: EdgeInsets.only(
                      left: widget.isMine ? 0 : 10,
                      right: widget.isMine ? 10 : 0,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.reply_rounded,
                      color: const Color(0xFF7C3AED),
                      size: 19,
                      textDirection: widget.isMine ? TextDirection.rtl : TextDirection.ltr,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
