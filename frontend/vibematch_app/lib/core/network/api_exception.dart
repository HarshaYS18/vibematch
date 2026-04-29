class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.body,
  });

  final String message;
  final int? statusCode;
  final Object? body;

  @override
  String toString() {
    final codeText = statusCode == null ? '' : ' [$statusCode]';
    return 'ApiException$codeText: $message';
  }
}
