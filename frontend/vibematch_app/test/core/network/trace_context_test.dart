import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/core/network/trace_context.dart';

void main() {
  test('traceparent is valid W3C version 00 shape', () {
    final value = TraceContext.newTraceparent();
    expect(
      RegExp(r'^00-[0-9a-f]{32}-[0-9a-f]{16}-01$').hasMatch(value),
      isTrue,
    );
    expect(value.substring(3, 35), isNot('00000000000000000000000000000000'));
    expect(value.substring(36, 52), isNot('0000000000000000'));
  });

  test('caller supplied traceparent is preserved', () {
    const supplied =
        '00-0123456789abcdef0123456789abcdef-0123456789abcdef-01';
    final headers = TraceContext.withTraceparent(
      const <String, String>{'traceparent': supplied},
    );
    expect(headers['traceparent'], supplied);
  });
}
