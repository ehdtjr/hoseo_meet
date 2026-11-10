import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart';
import '../../features/auth/providers/auth_notifier_provider.dart';

class AuthHttpClient {
  final Ref _ref;
  final http.Client _client;
  final Directory _temporaryDirectory;

  AuthHttpClient(this._ref,
      {http.Client? client, Directory? temporaryDirectory})
      : _client = client ?? http.Client(),
        _temporaryDirectory = temporaryDirectory ?? Directory.systemTemp;

  void close() => _client.close();

  // Each attempt gets a fresh request. Bodies are replayed from an immutable
  // small encoded body or a disk snapshot, never a consumed request stream.
  Future<http.Response> _sendAuthenticated(
      http.BaseRequest Function() createRequest) async {
    try {
      Future<http.Response> send(String token) async {
        final attempt = createRequest()
          ..headers['Authorization'] = 'Bearer $token';
        return http.Response.fromStream(await _client.send(attempt));
      }

      final notifier = _ref.read(authNotifierProvider.notifier);
      final revision = notifier.sessionRevision;
      final token = _ref.read(authNotifierProvider).accessToken;
      if (token == null) return http.Response('No access token', 401);
      final response = await send(token);
      if (response.statusCode != 401) return response;

      if (notifier.sessionRevision != revision ||
          !await notifier.refreshRejectedToken(token) ||
          notifier.sessionRevision != revision) return response;
      final auth = _ref.read(authNotifierProvider);
      if (!auth.isLoggedIn || auth.accessToken == null) return response;
      // A second 401 is returned to the caller, never recursively retried.
      return await send(auth.accessToken!);
    } catch (e) {
      return http.Response('Error: $e', 500);
    }
  }

  Future<http.Response> _sendRequest(
    String url,
    String method, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    Map<String, String>? formFields,
    bool isFormEncoded = false,
  }) {
    final request = http.Request(method, Uri.parse(url));
    request.headers['Content-Type'] = isFormEncoded
        ? 'application/x-www-form-urlencoded'
        : 'application/json';
    if (headers != null) request.headers.addAll(headers);
    if (isFormEncoded) {
      request.bodyFields = Map<String, String>.of(formFields ?? {});
    } else if (method != 'GET') {
      request.body = jsonEncode(body);
    }
    final encodedHeaders = Map<String, String>.of(request.headers);
    final encodedBody = request.bodyBytes;
    return _sendAuthenticated(() => http.Request(method, request.url)
      ..headers.addAll(encodedHeaders)
      ..bodyBytes = encodedBody);
  }

  Future<http.Response> getRequest(String url) => _sendRequest(url, 'GET');

  Future<http.Response> postRequest(String url, Map<String, dynamic> body,
          {Map<String, String>? headers}) =>
      _sendRequest(url, 'POST', body: body, headers: headers);

  Future<http.Response> postFormUrlEncoded(
          String url, Map<String, String> formFields,
          {Map<String, String>? headers}) =>
      _sendRequest(url, 'POST',
          formFields: formFields, isFormEncoded: true, headers: headers);

  Future<http.Response> deleteRequest(String url,
          {Map<String, dynamic>? body}) =>
      _sendRequest(url, 'DELETE', body: body);

  Future<http.Response> postSingleMultipartRequest(
          String url, String key, File file) =>
      postMultipleMultipartRequest(url, key, [file]);

  Future<http.Response> postMultipleMultipartRequest(
    String url,
    String key,
    List<File> files, {
    Map<String, String>? additionalFields,
  }) async {
    if (_ref.read(authNotifierProvider).accessToken == null) {
      return http.Response('No access token', 401);
    }
    // Copy caller-owned collections before the first await.
    final paths = files.map((file) => file.path).toList();
    final request = http.MultipartRequest('POST', Uri.parse(url));
    if (additionalFields != null) request.fields.addAll(additionalFields);
    Directory? snapshotDirectory;
    try {
      for (final path in paths) {
        final fileName = basename(path);
        request.files.add(await http.MultipartFile.fromPath(
          key,
          path,
          contentType: MediaType('image', extension(path).replaceAll('.', '')),
          filename: fileName,
        ));
      }
      snapshotDirectory =
          await _temporaryDirectory.createTemp('campusmeet-upload-');
      final bodyFile = File('${snapshotDirectory.path}/body');
      final sink = bodyFile.openWrite();
      try {
        // MultipartRequest emits file chunks; addStream applies backpressure.
        // Finalizing also chooses the boundary copied into each attempt.
        await sink.addStream(request.finalize());
      } finally {
        await sink.close();
      }
      final encodedHeaders = Map<String, String>.of(request.headers);
      final length = await bodyFile.length();
      return await _sendAuthenticated(() => _FileBodyRequest(
            request.method,
            request.url,
            bodyFile,
            length,
          )..headers.addAll(encodedHeaders));
    } catch (e) {
      return http.Response('Error uploading images: $e', 500);
    } finally {
      if (snapshotDirectory != null) {
        try {
          await snapshotDirectory.delete(recursive: true);
        } on FileSystemException catch (error) {
          // A cleanup failure must not turn an acknowledged upload into a
          // failed upload that the caller could duplicate by retrying.
          debugPrint('[AuthHttpClient] Upload snapshot cleanup failed: $error');
        }
      }
    }
  }

  // Arbitrary streaming bodies cannot be replayed safely.
  Future<http.StreamedResponse> sendStreamRequest(
      http.BaseRequest request) async {
    final token = _ref.read(authNotifierProvider).accessToken;
    if (token == null) throw Exception('No access token');
    request.headers['Authorization'] = 'Bearer $token';
    return _client.send(request);
  }
}

// Reopening the snapshot makes retries byte-identical without retaining a
// multi-file upload in RAM. The snapshot outlives both HTTP attempts.
class _FileBodyRequest extends http.BaseRequest {
  final File _bodyFile;

  _FileBodyRequest(super.method, super.url, this._bodyFile, int length) {
    contentLength = length;
  }

  @override
  http.ByteStream finalize() {
    super.finalize();
    return http.ByteStream(_bodyFile.openRead());
  }
}
