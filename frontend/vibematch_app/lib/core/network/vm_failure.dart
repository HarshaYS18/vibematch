import 'api_exception.dart';

enum VmFailureKind {
  offline,
  timeout,
  unauthenticated,
  forbidden,
  notFound,
  rateLimited,
  server,
  cancelled,
  unknown,
}

class VmFailurePresentation {
  const VmFailurePresentation({
    required this.kind,
    required this.title,
    required this.message,
    required this.retryable,
  });

  final VmFailureKind kind;
  final String title;
  final String message;
  final bool retryable;

  static VmFailurePresentation from(
    Object? error, {
    String contentLabel = 'content',
    String? fallbackMessage,
  }) {
    final status = _statusCode(error);
    final raw = _rawMessage(error);
    final lower = raw.toLowerCase();

    if (_looksCancelled(lower)) {
      return const VmFailurePresentation(
        kind: VmFailureKind.cancelled,
        title: 'Cancelled',
        message: 'This request was cancelled.',
        retryable: true,
      );
    }

    if (_looksTimedOut(lower)) {
      return const VmFailurePresentation(
        kind: VmFailureKind.timeout,
        title: 'Taking too long',
        message: 'This is taking longer than expected. Check your connection and try again.',
        retryable: true,
      );
    }

    if (_looksOffline(lower)) {
      return const VmFailurePresentation(
        kind: VmFailureKind.offline,
        title: 'No connection',
        message: 'You appear to be offline. Check your connection and try again.',
        retryable: true,
      );
    }

    if (status == 401) {
      return const VmFailurePresentation(
        kind: VmFailureKind.unauthenticated,
        title: 'Session expired',
        message: 'Your session has expired. Sign in again to continue.',
        retryable: false,
      );
    }

    if (status == 403) {
      return const VmFailurePresentation(
        kind: VmFailureKind.forbidden,
        title: 'Not available',
        message: 'You do not have access to this right now.',
        retryable: false,
      );
    }

    if (status == 404) {
      return VmFailurePresentation(
        kind: VmFailureKind.notFound,
        title: 'Not found',
        message: 'This $contentLabel is no longer available.',
        retryable: false,
      );
    }

    if (status == 429) {
      return const VmFailurePresentation(
        kind: VmFailureKind.rateLimited,
        title: 'Try again shortly',
        message: 'Too many requests were made at once. Wait a moment and try again.',
        retryable: true,
      );
    }

    if (status != null && status >= 500) {
      return VmFailurePresentation(
        kind: VmFailureKind.server,
        title: 'Service unavailable',
        message: 'FunKey is having trouble loading $contentLabel right now. Please try again.',
        retryable: true,
      );
    }

    final safeDetail = _safeDetail(error);
    if (safeDetail != null && safeDetail.isNotEmpty) {
      return VmFailurePresentation(
        kind: VmFailureKind.unknown,
        title: 'Could not complete that',
        message: safeDetail,
        retryable: true,
      );
    }

    return VmFailurePresentation(
      kind: VmFailureKind.unknown,
      title: 'Could not load $contentLabel',
      message: fallbackMessage?.trim().isNotEmpty == true
          ? fallbackMessage!.trim()
          : 'We could not load $contentLabel right now. Please try again.',
      retryable: true,
    );
  }

  static String messageFor(
    Object? error, {
    String contentLabel = 'content',
    String? fallbackMessage,
  }) {
    return from(
      error,
      contentLabel: contentLabel,
      fallbackMessage: fallbackMessage,
    ).message;
  }

  static int? _statusCode(Object? error) {
    if (error is ApiException) return error.statusCode;
    final text = error?.toString() ?? '';
    final match = RegExp(r'\[(\d{3})\]').firstMatch(text);
    return match == null ? null : int.tryParse(match.group(1) ?? '');
  }

  static String _rawMessage(Object? error) {
    if (error is ApiException) {
      return '${error.message} ${_bodyDetail(error.body) ?? ''}'.trim();
    }
    return (error?.toString() ?? '').trim();
  }

  static String? _safeDetail(Object? error) {
    String raw;
    if (error is ApiException) {
      if (error.statusCode != null && error.statusCode! >= 500) return null;
      raw = _bodyDetail(error.body) ?? error.message;
    } else {
      raw = error?.toString() ?? '';
    }

    var text = raw
        .replaceFirst(RegExp(r'^Exception:\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^ApiException(?:\s*\[\d{3}\])?:\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final lower = text.toLowerCase();
    if (text.isEmpty ||
        lower == 'request failed' ||
        lower.contains('network request failed') ||
        lower.contains('socketexception') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('failed host lookup')) {
      return null;
    }

    if (text.length > 140) {
      text = '${text.substring(0, 137)}...';
    }
    return text;
  }

  static String? _bodyDetail(Object? body) {
    if (body is Map) {
      final detail = body['detail'] ?? body['message'] ?? body['error'];
      if (detail is String && detail.trim().isNotEmpty) return detail.trim();
    }
    if (body is String && body.trim().isNotEmpty) return body.trim();
    return null;
  }

  static bool _looksOffline(String lower) {
    return lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('connection error') ||
        lower.contains('network request failed') ||
        lower.contains('connectionerror') ||
        lower.contains('unknownhost');
  }

  static bool _looksTimedOut(String lower) {
    return lower.contains('timeout') ||
        lower.contains('timed out') ||
        lower.contains('connectiontimeout') ||
        lower.contains('receivetimeout') ||
        lower.contains('sendtimeout');
  }

  static bool _looksCancelled(String lower) {
    return lower.contains('cancelled') || lower.contains('canceled');
  }
}
