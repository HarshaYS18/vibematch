import 'package:flutter/material.dart';

class VmGradientNameText extends StatelessWidget {
  const VmGradientNameText({
    super.key,
    required this.text,
    required this.style,
    this.gradientColors = const <String>[],
    this.textAlign,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  final String text;
  final TextStyle style;
  final List<String> gradientColors;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    final colors = gradientColors
        .map(_colorFromHex)
        .whereType<Color>()
        .toList(growable: false);

    if (colors.length < 2) {
      return Text(
        text,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        style: style,
      );
    }

    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      child: Text(
        text,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        style: style.copyWith(color: Colors.white),
      ),
    );
  }
}

Color? _colorFromHex(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final normalized = text.startsWith('#') ? text.substring(1) : text;
  if (normalized.length != 6 && normalized.length != 8) return null;
  final value = int.tryParse(normalized, radix: 16);
  if (value == null) return null;
  return Color(normalized.length == 6 ? 0xFF000000 | value : value);
}
