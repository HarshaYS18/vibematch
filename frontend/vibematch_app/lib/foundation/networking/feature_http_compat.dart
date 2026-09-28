import 'dart:convert';

import 'app_network_client.dart';

class Response {
  const Response(
    this.body,
    this.statusCode, {
    this.headers = const <String, String>{},
  });

  final String body;
  final int statusCode;
  final Map<String, String> headers;

  List<int> get bodyBytes => utf8.encode(body);

  static Future<Response> fromStream(StreamedResponse response) async =>
      Response(
        response.body,
        response.statusCode,
        headers: response.headers,
      );
}

class StreamedResponse {
  const StreamedResponse(
    this.body,
    this.statusCode, {
    this.headers = const <String, String>{},
  });

  final String body;
  final int statusCode;
  final Map<String, String> headers;
}

class MultipartFile {
  const MultipartFile._(this.field, this.bytes, this.filename);

  final String field;
  final List<int> bytes;
  final String filename;

  factory MultipartFile.fromBytes(
    String field,
    List<int> bytes, {
    required String filename,
  }) =>
      MultipartFile._(field, bytes, filename);
}

class MultipartRequest {
  MultipartRequest(this.method, this.url);

  final String method;
  final Uri url;
  final Map<String, String> headers = <String, String>{};
  final Map<String, String> fields = <String, String>{};
  final List<MultipartFile> files = <MultipartFile>[];

  Future<StreamedResponse> send() async {
    final response = await AppNetworkRuntime.shared.request(
      method,
      url.toString(),
      headers: headers,
      body: NetworkMultipartBody(
        fields: fields,
        files: <NetworkMultipartFile>[
          for (final file in files)
            NetworkMultipartFile(
              field: file.field,
              filename: file.filename,
              bytes: file.bytes,
            ),
        ],
      ),
      throwOnHttpError: false,
    );
    return StreamedResponse(
      response.body,
      response.statusCode,
      headers: response.headers,
    );
  }
}

Future<Response> get(Uri url, {Map<String, String>? headers}) =>
    _request('GET', url, headers: headers);

Future<Response> post(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) =>
    _request('POST', url, headers: headers, body: body);

Future<Response> put(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) =>
    _request('PUT', url, headers: headers, body: body);

Future<Response> patch(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) =>
    _request('PATCH', url, headers: headers, body: body);

Future<Response> delete(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) =>
    _request('DELETE', url, headers: headers, body: body);

Future<Response> _request(
  String method,
  Uri url, {
  Map<String, String>? headers,
  Object? body,
}) async {
  final response = await AppNetworkRuntime.shared.request(
    method,
    url.toString(),
    headers: headers ?? const <String, String>{},
    body: body,
    throwOnHttpError: false,
  );
  return Response(
    response.body,
    response.statusCode,
    headers: response.headers,
  );
}
