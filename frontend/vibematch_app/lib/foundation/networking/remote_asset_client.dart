import 'dart:typed_data';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_exception.dart';
import 'canonical_network_transport.dart';

abstract interface class RemoteAssetClient {
  Future<Uint8List> getBytes(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  });

  void close();
}

/// Binary CDN client backed by FunKey's single canonical Dio owner.
class HttpRemoteAssetClient implements RemoteAssetClient {
  HttpRemoteAssetClient({CanonicalNetworkTransport? transport})
      : _transport = transport ?? CanonicalNetworkTransport.instance;

  final CanonicalNetworkTransport _transport;

  @override
  Future<Uint8List> getBytes(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    if (uri.scheme.toLowerCase() != 'https') {
      throw RemoteAssetException('Remote game assets must use HTTPS.', uri: uri);
    }

    try {
      return await _transport.getBytes(
        uri,
        headers: <String, String>{
          'Accept': 'application/json,text/html;q=0.9,*/*;q=0.8',
          ...headers,
        },
        timeout: AppConstants.receiveTimeout,
      );
    } on ApiException catch (error) {
      final status = error.statusCode;
      throw RemoteAssetException(
        status == null
            ? 'Remote asset request failed.'
            : 'Remote asset request failed ($status).',
        uri: uri,
      );
    } catch (error) {
      throw RemoteAssetException(
        'Remote asset request failed: ${error.runtimeType}.',
        uri: uri,
      );
    }
  }

  @override
  void close() {
    // CanonicalNetworkTransport is process-scoped and intentionally reused.
  }
}

class RemoteAssetException implements Exception {
  const RemoteAssetException(this.message, {this.uri});

  final String message;
  final Uri? uri;

  @override
  String toString() => message;
}
