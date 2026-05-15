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

class _GradientNameTextState extends State<GradientNameText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
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
          builder: (context, _) {
            final slide = widget.style.isAnimated ? (_controller.value * 0.55) : 0.0;
            final segments = _splitGradientNameText(widget.text);

            return Text.rich(
              TextSpan(
                children: segments.map((segment) {
                  if (segment.isEmoji) {
                    return TextSpan(text: segment.text, style: baseStyle);
                  }

                  return WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          begin: Alignment(-1.0 + slide, -0.6),
                          end: Alignment(1.0 + slide, 0.6),
                          colors: widget.style.colors,
                        ).createShader(bounds);
                      },
                      child: Text(
                        segment.text,
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        style: baseStyle.copyWith(color: Colors.white),
                      ),
                    ),
                  );
                }).toList(growable: false),
              ),
              maxLines: widget.maxLines,
              overflow: widget.overflow,
              textAlign: widget.textAlign,
            );
          },
        ),
      ),
    );
  }
}

class _GradientNameSegment {
  const _GradientNameSegment({required this.text, required this.isEmoji});

  final String text;
  final bool isEmoji;
}

List<_GradientNameSegment> _splitGradientNameText(String text) {
  if (text.isEmpty) return const <_GradientNameSegment>[];

  final segments = <_GradientNameSegment>[];
  final buffer = StringBuffer();
  bool? currentIsEmoji;

  void flush() {
    final isEmoji = currentIsEmoji;
    if (buffer.isEmpty || isEmoji == null) return;
    segments.add(
      _GradientNameSegment(text: buffer.toString(), isEmoji: isEmoji),
    );
    buffer.clear();
  }

  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    final isEmoji = _isEmojiCodePoint(rune);
    if (currentIsEmoji == null) {
      currentIsEmoji = isEmoji;
    } else if (currentIsEmoji != isEmoji) {
      flush();
      currentIsEmoji = isEmoji;
    }
    buffer.write(char);
  }

  flush();
  return segments;
}

bool _isEmojiCodePoint(int codePoint) {
  return codePoint == 0x200D ||
      codePoint == 0x20E3 ||
      codePoint == 0xFE0E ||
      codePoint == 0xFE0F ||
      (codePoint >= 0x1F1E6 && codePoint <= 0x1F1FF) ||
      (codePoint >= 0x1F300 && codePoint <= 0x1FAFF) ||
      (codePoint >= 0x2600 && codePoint <= 0x27BF) ||
      (codePoint >= 0xE0020 && codePoint <= 0xE007F);
}
