import 'dart:math';

class TraceContext {
  TraceContext._();

  static final Random _random = Random.secure();

  static String newTraceparent() {
    final traceId = _hexBytes(16, requireNonZero: true);
    final spanId = _hexBytes(8, requireNonZero: true);
    return '00-$traceId-$spanId-01';
  }

  static Map<String, String> withTraceparent(
    Map<String, String> headers,
  ) {
    if (headers.keys.any((key) => key.toLowerCase() == 'traceparent')) {
      return Map<String, String>.from(headers);
    }
    return <String, String>{
      'traceparent': newTraceparent(),
      ...headers,
    };
  }

  static String _hexBytes(int count, {required bool requireNonZero}) {
    while (true) {
      final buffer = StringBuffer();
      var nonZero = false;
      for (var i = 0; i < count; i += 1) {
        final value = _random.nextInt(256);
        if (value != 0) nonZero = true;
        buffer.write(value.toRadixString(16).padLeft(2, '0'));
      }
      if (!requireNonZero || nonZero) return buffer.toString();
    }
  }
}
