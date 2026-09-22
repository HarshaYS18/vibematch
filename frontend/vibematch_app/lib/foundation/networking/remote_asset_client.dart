import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';

abstract interface class RemoteAssetClient {
  Future<Uint8List> getBytes(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  });

  void close();
}

class HttpRemoteAssetClient implements RemoteAssetClient {
  HttpRemoteAssetClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<Uint8List> getBytes(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    if (uri.scheme.toLowerCase() != 'https') {
      throw RemoteAssetException('Remote game assets must use HTTPS.', uri: uri);
    }

    final response = await _client
        .get(
          uri,
          headers: <String, String>{
            'Accept': 'application/json,text/html;q=0.9,*/*;q=0.8',
            ...headers,
          },
        )
        .timeout(AppConstants.receiveTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RemoteAssetException(
        'Remote asset request failed (${response.statusCode}).',
        uri: uri,
      );
    }
    return Uint8List.fromList(response.bodyBytes);
  }

  @override
  void close() => _client.close();
}

class RemoteAssetException implements Exception {
  const RemoteAssetException(this.message, {this.uri});

  final String message;
  final Uri? uri;

  @override
  String toString() => message;
}
