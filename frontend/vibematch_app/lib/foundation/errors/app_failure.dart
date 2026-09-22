enum AppFailureKind {
  network,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  validation,
  unavailable,
  unknown,
}

class AppFailure implements Exception {
  const AppFailure({
    required this.kind,
    required this.message,
    this.statusCode,
    this.cause,
  });

  final AppFailureKind kind;
  final String message;
  final int? statusCode;
  final Object? cause;

  bool get invalidatesSession =>
      kind == AppFailureKind.unauthorized ||
      kind == AppFailureKind.forbidden;

  @override
  String toString() => 'AppFailure($kind, $message, status=$statusCode)';
}
