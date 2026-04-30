import 'package:flutter/material.dart';

class VmAvatarFrameStyle {
  const VmAvatarFrameStyle({
    required this.id,
    required this.name,
    required this.accent,
    this.assetPath,
    this.isDynamic = false,
  });

  final String id;
  final String name;
  final Color accent;
  final String? assetPath;
  final bool isDynamic;
}

class VmAvatarFrameHost extends StatefulWidget {
  const VmAvatarFrameHost({
    super.key,
    required this.child,
    required this.size,
    this.frame,
    this.framePadding = 8,
    this.staticStrokeWidth = 2.2,
  });

  final Widget child;
  final double size;
  final VmAvatarFrameStyle? frame;
  final double framePadding;
  final double staticStrokeWidth;

  @override
  State<VmAvatarFrameHost> createState() => _VmAvatarFrameHostState();
}

class _VmAvatarFrameHostState extends State<VmAvatarFrameHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.frame?.isDynamic ?? false) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant VmAvatarFrameHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    final isDynamic = widget.frame?.isDynamic ?? false;
    if (isDynamic && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!isDynamic && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frame = widget.frame;
    if (frame == null) return widget.child;

    final frameSize = widget.size + widget.framePadding;

    return SizedBox(
      width: frameSize,
      height: frameSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (frame.assetPath != null)
            Image.asset(
              frame.assetPath!,
              width: frameSize,
              height: frameSize,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => _GeneratedVmAvatarFrame(
                frame: frame,
                size: frameSize,
                controller: _controller,
                staticStrokeWidth: widget.staticStrokeWidth,
              ),
            )
          else
            _GeneratedVmAvatarFrame(
              frame: frame,
              size: frameSize,
              controller: _controller,
              staticStrokeWidth: widget.staticStrokeWidth,
            ),
          widget.child,
        ],
      ),
    );
  }
}

class _GeneratedVmAvatarFrame extends StatelessWidget {
  const _GeneratedVmAvatarFrame({
    required this.frame,
    required this.size,
    required this.controller,
    required this.staticStrokeWidth,
  });

  final VmAvatarFrameStyle frame;
  final double size;
  final AnimationController controller;
  final double staticStrokeWidth;

  @override
  Widget build(BuildContext context) {
    if (!frame.isDynamic) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: frame.accent.withValues(alpha: 0.72),
            width: staticStrokeWidth,
          ),
          boxShadow: [
            BoxShadow(
              color: frame.accent.withValues(alpha: 0.18),
              blurRadius: 12,
            ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: controller.value * 6.28318,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  frame.accent.withValues(alpha: 0.10),
                  frame.accent.withValues(alpha: 0.88),
                  const Color(0xFF7A5CFF).withValues(alpha: 0.55),
                  frame.accent.withValues(alpha: 0.10),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: frame.accent.withValues(alpha: 0.22),
                  blurRadius: 16,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class VmAvatarCore extends StatelessWidget {
  const VmAvatarCore({
    super.key,
    required this.label,
    required this.colors,
    required this.size,
    this.borderColor = Colors.white,
    this.borderWidth = 4,
    this.textScale = 0.35,
  });

  final String label;
  final List<Color> colors;
  final double size;
  final Color borderColor;
  final double borderWidth;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(borderWidth),
      decoration: BoxDecoration(
        color: borderColor,
        shape: BoxShape.circle,
      ),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: colors),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * textScale,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ),
    );
  }
}
