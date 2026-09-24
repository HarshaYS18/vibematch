import 'dart:async';

import 'package:http/http.dart' as http;

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

class DirectUploadTransport {
  DirectUploadTransport({
    http.Client? client,
    this.timeout = const Duration(minutes: 10),
  }) : _client = client ?? http.Client();

  final http.Client _client;
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

    final request = http.StreamedRequest('PUT', url)
      ..headers.addAll(headers)
      ..contentLength = endExclusive - start;

    final responseFuture = _client.send(request).timeout(timeout);
    try {
      await request.sink
          .addStream(source.openRange(start, endExclusive))
          .timeout(timeout);
      await request.sink.close();
      final response = await responseFuture;
      await response.stream.drain<void>().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw DirectUploadTransportException(
          'Object upload failed (${response.statusCode}).',
          statusCode: response.statusCode,
        );
      }
      return response.headers['etag'];
    } catch (error) {
      try {
        await request.sink.close();
      } catch (_) {
        // Best-effort cleanup after a transport failure.
      }
      if (error is DirectUploadTransportException) rethrow;
      throw DirectUploadTransportException(
        'Object upload transport failed: ${error.runtimeType}.',
      );
    }
  }

  void close() => _client.close();
}
