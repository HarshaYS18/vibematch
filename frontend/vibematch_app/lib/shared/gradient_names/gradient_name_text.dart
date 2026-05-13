import 'package:flutter/material.dart';

import 'gradient_name_style.dart';

class GradientNameText extends StatefulWidget {
  const GradientNameText(
    this.text, {
    super.key,
    this.style = GradientNameStyle.defaultName,
    this.textStyle,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.textAlign,
    this.semanticsLabel,
  });

  final String text;
  final GradientNameStyle style;
  final TextStyle? textStyle;
  final int? maxLines;
  final TextOverflow overflow;
  final TextAlign? textAlign;
  final String? semanticsLabel;

  @override
  State<GradientNameText> createState() => _GradientNameTextState();
}

class _GradientNameTextState extends State<GradientNameText> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    if (widget.style.isAnimated) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant GradientNameText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.style.isAnimated != widget.style.isAnimated) {
      if (widget.style.isAnimated) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = widget.textStyle ?? DefaultTextStyle.of(context).style;
    if (widget.style.id == GradientNameStyle.defaultName.id) {
      return Text(
        widget.text,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
        textAlign: widget.textAlign,
        semanticsLabel: widget.semanticsLabel,
        style: baseStyle,
      );
    }

    return Semantics(
      label: widget.semanticsLabel ?? widget.text,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final slide = widget.style.isAnimated ? (_controller.value * 0.55) : 0.0;
            return ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) {
                return LinearGradient(
                  begin: Alignment(-1.0 + slide, -0.6),
                  end: Alignment(1.0 + slide, 0.6),
                  colors: widget.style.colors,
                ).createShader(bounds);
              },
              child: child,
            );
          },
          child: Text(
            widget.text,
            maxLines: widget.maxLines,
            overflow: widget.overflow,
            textAlign: widget.textAlign,
            style: baseStyle.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
