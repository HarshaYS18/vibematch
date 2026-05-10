import 'package:flutter/material.dart';

import '../../models/vip_wallet_models.dart';

class SvipGradientName extends StatefulWidget {
  const SvipGradientName({
    super.key,
    required this.name,
    required this.vip,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.enableFloat = true,
  });

  final String name;
  final UserVipSummary vip;
  final TextStyle? style;
  final int maxLines;
  final TextOverflow overflow;
  final bool enableFloat;

  @override
  State<SvipGradientName> createState() => _SvipGradientNameState();
}

class _SvipGradientNameState extends State<SvipGradientName> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
    if (widget.vip.hasActiveSvipGradient && widget.enableFloat) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant SvipGradientName oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldAnimate = widget.vip.hasActiveSvipGradient && widget.enableFloat;
    if (shouldAnimate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!shouldAnimate && _controller.isAnimating) {
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
    final baseStyle = widget.style ?? const TextStyle(fontSize: 14, fontWeight: FontWeight.w900);
    if (!widget.vip.hasActiveSvipGradient) {
      return Text(widget.name, maxLines: widget.maxLines, overflow: widget.overflow, style: baseStyle);
    }

    final colors = widget.vip.nameGradientColors.map(_parseColor).toList(growable: false);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final lift = widget.enableFloat ? -1.5 * _controller.value : 0.0;
        final begin = Alignment(-1.0 + (_controller.value * 0.7), -0.5);
        final end = Alignment(1.0 - (_controller.value * 0.7), 0.5);
        return Transform.translate(
          offset: Offset(0, lift),
          child: ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => LinearGradient(
              begin: begin,
              end: end,
              colors: colors,
            ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
            child: Text(
              widget.name,
              maxLines: widget.maxLines,
              overflow: widget.overflow,
              style: baseStyle.copyWith(
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: colors.last.withValues(alpha: 0.35),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _parseColor(String raw) {
    final value = raw.trim().replaceFirst('#', '');
    final normalized = value.length == 6 ? 'FF$value' : value;
    return Color(int.tryParse(normalized, radix: 16) ?? 0xFFFFFFFF);
  }
}
