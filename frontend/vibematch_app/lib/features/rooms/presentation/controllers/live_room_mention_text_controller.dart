import 'package:flutter/material.dart';

class LiveRoomMentionTextController extends TextEditingController {
  LiveRoomMentionTextController({super.text});

  static const Color _mentionColor = Color(0xFF18C7B7);

  final Set<String> _trackedMentionNames = <String>{};

  void registerMention(String displayName) {
    final clean = displayName.trim();
    if (clean.isEmpty) return;
    _trackedMentionNames.add(clean);
  }

  void insertMention(String displayName) {
    final clean = displayName.trim();
    if (clean.isEmpty) return;

    registerMention(clean);

    final mention = '@$clean ';
    final currentText = text;
    final selectionRange = selection;

    final start = selectionRange.isValid ? selectionRange.start : currentText.length;
    final end = selectionRange.isValid ? selectionRange.end : currentText.length;

    final before = currentText.substring(0, start);
    final after = currentText.substring(end);

    final needsSpaceBefore = before.isNotEmpty && !before.endsWith(' ');
    final insertText = needsSpaceBefore ? ' $mention' : mention;

    final updatedText = '$before$insertText$after';
    final cursor = before.length + insertText.length;

    value = TextEditingValue(
      text: updatedText,
      selection: TextSelection.collapsed(offset: cursor),
      composing: TextRange.empty,
    );
  }

  bool _matchesTrackedMentionAt(String source, int index, String displayName) {
    final mention = '@$displayName';
    if (!source.startsWith(mention, index)) return false;

    final end = index + mention.length;
    if (end >= source.length) return true;

    final next = source[end];

    // The tracked mention remains valid only when the exact inserted mention
    // text still exists. If the user backspaces inside it, this check fails
    // and the highlight disappears automatically.
    return next.trim().isEmpty ||
        next == ',' ||
        next == '.' ||
        next == '!' ||
        next == '?' ||
        next == ':' ||
        next == ';';
  }

  String? _trackedMentionAt(String source, int index) {
    if (source[index] != '@') return null;

    final candidates = _trackedMentionNames.toList(growable: false)
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final name in candidates) {
      if (_matchesTrackedMentionAt(source, index, name)) {
        return '@$name';
      }
    }

    return null;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();
    final mentionStyle = baseStyle.copyWith(
      color: _mentionColor,
      fontWeight: FontWeight.w900,
    );

    final source = text;
    if (source.isEmpty) {
      return TextSpan(style: baseStyle, text: '');
    }

    final children = <InlineSpan>[];
    final normalBuffer = StringBuffer();

    var index = 0;
    while (index < source.length) {
      final mention = source[index] == '@' ? _trackedMentionAt(source, index) : null;

      if (mention != null) {
        if (normalBuffer.isNotEmpty) {
          children.add(TextSpan(text: normalBuffer.toString(), style: baseStyle));
          normalBuffer.clear();
        }

        children.add(TextSpan(text: mention, style: mentionStyle));
        index += mention.length;
        continue;
      }

      normalBuffer.write(source[index]);
      index++;
    }

    if (normalBuffer.isNotEmpty) {
      children.add(TextSpan(text: normalBuffer.toString(), style: baseStyle));
    }

    return TextSpan(style: baseStyle, children: children);
  }
}
