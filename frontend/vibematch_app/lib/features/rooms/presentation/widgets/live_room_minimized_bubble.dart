import 'package:flutter/material.dart';

import 'room_theme.dart';

class LiveRoomMinimizedBubble extends StatefulWidget {
  const LiveRoomMinimizedBubble({
    super.key,
    required this.offset,
    required this.onRestore,
    required this.onDrag,
  });

  final Offset offset;
  final VoidCallback onRestore;
  final ValueChanged<DragUpdateDetails> onDrag;

  @override
  State<LiveRoomMinimizedBubble> createState() =>
      _LiveRoomMinimizedBubbleState();
}

class _LiveRoomMinimizedBubbleState extends State<LiveRoomMinimizedBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  bool _pressed = false;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 310),
    );

    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuart,
      reverseCurve: Curves.easeInCubic,
    );

    _fade = Tween<double>(begin: 0, end: 1).animate(curved);
    _scale = Tween<double>(begin: 0.78, end: 1).animate(curved);
    _slide = Tween<Offset>(
      begin: const Offset(-0.22, 0.08),
      end: Offset.zero,
    ).animate(curved);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (_pressed == value || _restoring) return;
    setState(() => _pressed = value);
  }

  Future<void> _restoreWithTransition() async {
    if (_restoring) return;
    setState(() {
      _restoring = true;
      _pressed = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 110));

    if (!mounted) return;
    await _controller.reverse();

    if (!mounted) return;
    widget.onRestore();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.offset.dx,
      top: widget.offset.dy,
      child: RepaintBoundary(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: ScaleTransition(
              scale: _scale,
              child: GestureDetector(
                onTap: _restoreWithTransition,
                onPanUpdate: _restoring ? null : widget.onDrag,
                onTapDown: (_) => _setPressed(true),
                onTapCancel: () => _setPressed(false),
                onTapUp: (_) => _setPressed(false),
                child: AnimatedScale(
                  scale: _restoring
                      ? 0.76
                      : _pressed
                      ? 0.94
                      : 1.0,
                  duration: Duration(milliseconds: _restoring ? 260 : 140),
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    opacity: _restoring ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    child: Material(
                      type: MaterialType.transparency,
                      child: Container(
                        width: 78,
                        height: 54,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: const LinearGradient(
                            colors: [RoomColors.aqua, RoomColors.violet],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: RoomColors.aqua.withValues(alpha: 0.30),
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: RoomColors.violet.withValues(alpha: 0.20),
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.graphic_eq_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Live',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                decoration: TextDecoration.none,
                                decorationColor: Colors.transparent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
