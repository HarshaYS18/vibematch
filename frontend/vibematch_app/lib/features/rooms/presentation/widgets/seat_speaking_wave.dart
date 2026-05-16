import 'package:flutter/material.dart';

import 'room_theme.dart';

class SeatSpeakingWave extends StatefulWidget {
  const SeatSpeakingWave({
    super.key,
    required this.size,
    required this.active,
    this.child,
  });

  final double size;
  final bool active;
  final Widget? child;

  @override
  State<SeatSpeakingWave> createState() => _SeatSpeakingWaveState();
}

class _SeatSpeakingWaveState extends State<SeatSpeakingWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    );
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant SeatSpeakingWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    if (widget.active) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size + 16,
      height: widget.size + 16,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (widget.active) ...[
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = Curves.easeOut.transform(_controller.value);
                return _WaveRing(
                  size: widget.size + 5 + (t * 11),
                  opacity: (1 - t) * 0.34,
                  width: 1.25,
                );
              },
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final raw = (_controller.value + 0.48) % 1.0;
                final t = Curves.easeOut.transform(raw);
                return _WaveRing(
                  size: widget.size + 4 + (t * 10),
                  opacity: (1 - t) * 0.24,
                  width: 1.05,
                );
              },
            ),
            Container(
              width: widget.size + 4,
              height: widget.size + 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: RoomColors.aqua.withValues(alpha: 0.56),
                  width: 1.15,
                ),
                boxShadow: [
                  BoxShadow(
                    color: RoomColors.aqua.withValues(alpha: 0.22),
                    blurRadius: 9,
                    spreadRadius: 0.7,
                  ),
                ],
              ),
            ),
          ],
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

class _WaveRing extends StatelessWidget {
  const _WaveRing({
    required this.size,
    required this.opacity,
    required this.width,
  });

  final double size;
  final double opacity;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: RoomColors.aqua.withValues(alpha: opacity.clamp(0.0, 1.0)),
          width: width,
        ),
      ),
    );
  }
}
