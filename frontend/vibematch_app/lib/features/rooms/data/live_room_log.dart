import 'package:flutter/foundation.dart';

/// Minimal logging policy for live-room signaling/media.
///
/// Default:
///   - normal traces: hidden
///   - transient warnings: hidden
///   - actionable errors: one compact line
///
/// Optional diagnostics:
///   --dart-define=VM_MEDIA_WARN_LOGS=true
///   --dart-define=VM_MEDIA_VERBOSE_LOGS=true
abstract final class LiveRoomLog {
  static const bool verbose = bool.fromEnvironment(
    'VM_MEDIA_VERBOSE_LOGS',
    defaultValue: false,
  );

  static const bool warnings = bool.fromEnvironment(
    'VM_MEDIA_WARN_LOGS',
    defaultValue: false,
  );

  static const int _maxMessageLength = 240;

  static void trace(String scope, String message) {
    if (!kDebugMode || !verbose) return;
    debugPrint('[FK:T:$scope] ${_compact(message)}');
  }

  static void warning(String scope, String message) {
    if (!kDebugMode || (!warnings && !verbose)) return;
    debugPrint('[FK:W:$scope] ${_compact(message)}');
  }

  static void error(String scope, String message) {
    if (!kDebugMode) return;
    debugPrint('[FK:E:$scope] ${_compact(message)}');
  }

  static String _compact(String message) {
    final singleLine = message.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (singleLine.length <= _maxMessageLength) return singleLine;
    return '${singleLine.substring(0, _maxMessageLength - 1)}…';
  }
}
