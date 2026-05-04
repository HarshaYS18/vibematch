import 'package:flutter/material.dart';

import '../../social/data/social_mock_data.dart';

class VibeMentionTextController extends TextEditingController {
  VibeMentionTextController({super.text});

  static final RegExp _mentionRegex = RegExp(r'@([a-zA-Z0-9_]{2,24}|all)');

  bool get hasMentionTrigger {
    final cursor = selection.baseOffset;
    if (cursor <= 0 || cursor > text.length) return false;
    final beforeCursor = text.substring(0, cursor);
    final lastAt = beforeCursor.lastIndexOf('@');
    if (lastAt < 0) return false;
    final afterAt = beforeCursor.substring(lastAt);
    return !afterAt.contains(' ') && afterAt.length <= 25;
  }

  String get activeMentionQuery {
    final cursor = selection.baseOffset;
    if (cursor <= 0 || cursor > text.length) return '';
    final beforeCursor = text.substring(0, cursor);
    final lastAt = beforeCursor.lastIndexOf('@');
    if (lastAt < 0) return '';
    final token = beforeCursor.substring(lastAt);
    if (token.contains(' ')) return '';
    return token;
  }

  int get mentionAllCount {
    return RegExp(r'(^|\s)@all\b', caseSensitive: false).allMatches(text).length;
  }

  bool get usesMentionAll => mentionAllCount > 0;

  List<String> get validMentions {
    return _mentionRegex
        .allMatches(text)
        .map((match) => match.group(1))
        .whereType<String>()
        .where((token) => token.toLowerCase() != 'all')
        .where((token) => SocialMockData.isValidMention(token))
        .map((token) => '${token[0].toUpperCase()}${token.substring(1)}')
        .toSet()
        .toList();
  }

  void insertMention(String username) {
    final clean = username.replaceFirst('@', '').trim();
    if (clean.isEmpty) return;

    final cursor = selection.baseOffset < 0 ? text.length : selection.baseOffset;
    final beforeCursor = text.substring(0, cursor);
    final afterCursor = text.substring(cursor);
    final lastAt = beforeCursor.lastIndexOf('@');

    final before = lastAt >= 0 && !beforeCursor.substring(lastAt).contains(' ')
        ? beforeCursor.substring(0, lastAt)
        : beforeCursor;
    final insert = '@$clean ';
    value = TextEditingValue(
      text: '$before$insert$afterCursor',
      selection: TextSelection.collapsed(offset: before.length + insert.length),
    );
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final defaultStyle = style ?? const TextStyle();
    final spans = <TextSpan>[];
    int index = 0;

    for (final match in _mentionRegex.allMatches(text)) {
      if (match.start > index) {
        spans.add(TextSpan(text: text.substring(index, match.start), style: defaultStyle));
      }

      final token = match.group(1) ?? '';
      final valid = token.toLowerCase() == 'all' || SocialMockData.isValidMention(token);
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: defaultStyle.copyWith(
            color: valid ? const Color(0xFF6D5DF6) : defaultStyle.color,
            fontWeight: valid ? FontWeight.w900 : defaultStyle.fontWeight,
          ),
        ),
      );
      index = match.end;
    }

    if (index < text.length) {
      spans.add(TextSpan(text: text.substring(index), style: defaultStyle));
    }

    return TextSpan(style: defaultStyle, children: spans);
  }
}
