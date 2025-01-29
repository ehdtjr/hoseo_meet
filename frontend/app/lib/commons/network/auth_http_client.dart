import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart';
import '../../features/auth/providers/auth_notifier_provider.dart';

class AuthHttpClient {
  final Ref _ref;

  AuthHttpClient(this._ref);

  /// ✅ 공통 요청 처리
  Future<http.Response> _sendRequest(
      String url,
      String method, {
        Map<String, String>? headers,
        Map<String, dynamic>? body,
        Map<String, String>? formFields,
        bool isFormEncoded = false,
      }) async {
    final authState = _ref.read(authNotifierProvider);
    final token = authState.accessToken;

    if (token == null) {
      return http.Response('No access token', 401);
    }

    final defaultHeaders = {
      'Authorization': 'Bearer $token',
      'Content-Type': isFormEncoded ? 'application/x-www-form-urlencoded' : 'application/json',
    };

    if (headers != null) {
      defaultHeaders.addAll(headers);
    }

    try {
      http.Response response;
      final uri = Uri.parse(url);

      switch (method) {
        case 'GET':
          response = await http.get(uri, headers: defaultHeaders);
          break;
        case 'POST':
          response = await http.post(
            uri,
            headers: defaultHeaders,
            body: isFormEncoded ? formFields : jsonEncode(body),
          );
          break;
        case 'DELETE':
          response = await http.delete(
            uri,
            headers: defaultHeaders,
            body: jsonEncode(body),
          );
          break;
        default:
          throw UnsupportedError('Method $method is not supported');
      }

      return await _handleUnauthorized(response, url, method, body: body, formFields: formFields);
    } catch (e) {
      return http.Response('Error: $e', 500);
    }
  }

  /// ✅ GET 요청
  Future<http.Response> getRequest(String url) async {
    return _sendRequest(url, 'GET');
  }

  /// ✅ POST 요청 (JSON Body)
  Future<http.Response> postRequest(String url, Map<String, dynamic> body) async {
    return _sendRequest(url, 'POST', body: body);
  }

  /// ✅ POST 요청 (x-www-form-urlencoded)
  Future<http.Response> postFormUrlEncoded(String url, Map<String, String> formFields) async {
    return _sendRequest(url, 'POST', formFields: formFields, isFormEncoded: true);
  }

  /// ✅ DELETE 요청
  Future<http.Response> deleteRequest(String url, {Map<String, dynamic>? body}) async {
    return _sendRequest(url, 'DELETE', body: body);
  }

  /// ✅ Multipart 파일 업로드 요청
  Future<http.Response> postMultipartRequest(String url, File file) async {
    final authState = _ref.read(authNotifierProvider);
    final token = authState.accessToken;

    if (token == null) {
      return http.Response('No access token', 401);
    }

    try {
      var request = http.MultipartRequest('POST', Uri.parse(url))
        ..headers.addAll({
          'Authorization': 'Bearer $token',
          'Content-Type': 'multipart/form-data',
        })
        ..files.add(await http.MultipartFile.fromPath(
          'file',
          file.path,
          contentType: MediaType('image', extension(file.path).replaceAll('.', '')),
        ));

      final streamedResponse = await request.send();
      return await http.Response.fromStream(streamedResponse);
    } catch (e) {
      return http.Response('Error uploading image: $e', 500);
    }
  }

  /// ✅ 401 처리 후 토큰 재발급 및 재시도
  Future<http.Response> _handleUnauthorized(
      http.Response response,
      String url,
      String method, {
        Map<String, dynamic>? body,
        Map<String, String>? formFields,
      }) async {
    if (response.statusCode == 401) {
      await _ref.read(authNotifierProvider.notifier).refreshAccessToken();
      final newToken = _ref.read(authNotifierProvider).accessToken;

      if (newToken != null) {
        return _sendRequest(url, method, body: body, formFields: formFields);
      }
    }
    return response;
  }
}
