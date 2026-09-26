import 'dart:async';

import 'canonical_network_transport.dart';

typedef UploadRangeStreamFactory = Stream<List<int>> Function(
  int start,
  int endExclusive,
);

class StreamingUploadSource {
  const StreamingUploadSource({
    required this.length,
    required this.openRange,
  });

  final int length;
  final UploadRangeStreamFactory openRange;
}

class DirectUploadTransportException implements Exception {
  const DirectUploadTransportException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Specialized streaming adapter for direct object-store uploads.
///
/// Dio ownership stays inside [CanonicalNetworkTransport]. This adapter keeps
/// media uploads streaming and preserves server-provided pre-signed headers.
class DirectUploadTransport {
  DirectUploadTransport({
    CanonicalNetworkTransport? transport,
    this.timeout = const Duration(minutes: 10),
  }) : _transport = transport ?? CanonicalNetworkTransport.instance;

  final CanonicalNetworkTransport _transport;
  final Duration timeout;

  Future<String?> putRange({
    required Uri url,
    required Map<String, String> headers,
    required StreamingUploadSource source,
    required int start,
    required int endExclusive,
  }) async {
    if (start < 0 ||
        endExclusive <= start ||
        endExclusive > source.length) {
      throw const DirectUploadTransportException(
        'Invalid upload byte range.',
      );
    }

    try {
      final response = await _transport.putStream(
        url,
        headers: headers,
        body: source.openRange(start, endExclusive),
        contentLength: endExclusive - start,
        timeout: timeout,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw DirectUploadTransportException(
          'Object upload failed (${response.statusCode}).',
          statusCode: response.statusCode,
        );
      }
      return response.headers['etag'];
    } catch (error) {
      if (error is DirectUploadTransportException) rethrow;
      throw DirectUploadTransportException(
        'Object upload transport failed: ${error.runtimeType}.',
      );
    }
  }

  void close() {
    // CanonicalNetworkTransport is process-scoped and intentionally reused.
  }
}
