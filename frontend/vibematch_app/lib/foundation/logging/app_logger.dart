import 'package:flutter/foundation.dart';

class AppLogger {
  const AppLogger();

  void debug(String scope, String message) {
    if (kDebugMode) {
      debugPrint('[FK:D:$scope] $message');
    }
  }

  void info(String scope, String message) {
    debugPrint('[FK:I:$scope] $message');
  }

  void warning(String scope, String message, [Object? error]) {
    debugPrint('[FK:W:$scope] $message${error == null ? '' : ' — $error'}');
  }

  void error(
    String scope,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    debugPrint('[FK:E:$scope] $message${error == null ? '' : ' — $error'}');
    if (kDebugMode && stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
