import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_notifier_provider.dart';

class AuthHttpClient {
  final Ref _ref;

  // 생성자에서 Ref를 받음
  AuthHttpClient(this._ref);

  Future<http.Response> getRequest(String url) async {
    final authState = _ref.read(authNotifierProvider);
    final token = authState.accessToken;

    if (token == null) {
      return http.Response('No access token', 401);
    }

    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    final response = await http.get(Uri.parse(url), headers: headers);

    if (response.statusCode == 401) {
      // 401 → 토큰 재발급 시도
      await _ref.read(authNotifierProvider.notifier).refreshAccessToken();

      // 재발급 후 새 토큰 얻기
      final newToken = _ref.read(authNotifierProvider).accessToken;
      if (newToken != null) {
        final retryHeaders = {
          'Authorization': 'Bearer $newToken',
          'Content-Type': 'application/json',
        };
        return http.get(Uri.parse(url), headers: retryHeaders);
      }
    }

    return response;
  }

  Future<http.Response> postRequest(String url, Map<String, dynamic> body) async {
    final authState = _ref.read(authNotifierProvider);
    final token = authState.accessToken;

    if (token == null) {
      return http.Response('No access token', 401);
    }

    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    var response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 401) {
      await _ref.read(authNotifierProvider.notifier).refreshAccessToken();

      final newToken = _ref.read(authNotifierProvider).accessToken;
      if (newToken != null) {
        final retryHeaders = {
          'Authorization': 'Bearer $newToken',
          'Content-Type': 'application/json',
        };
        response = await http.post(
          Uri.parse(url),
          headers: retryHeaders,
          body: jsonEncode(body),
        );
      }
    }

    return response;
  }

  Future<http.Response> postFormUrlEncoded(String url, Map<String, String> formFields) async {
    final authState = _ref.read(authNotifierProvider);
    final token = authState.accessToken;

    if (token == null) {
      return http.Response('No access token', 401);
    }

    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/x-www-form-urlencoded',
    };

    var response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: formFields,
    );

    if (response.statusCode == 401) {
      await _ref.read(authNotifierProvider.notifier).refreshAccessToken();

      final newToken = _ref.read(authNotifierProvider).accessToken;
      if (newToken != null) {
        final retryHeaders = {
          'Authorization': 'Bearer $newToken',
          'Content-Type': 'application/x-www-form-urlencoded',
        };
        response = await http.post(
          Uri.parse(url),
          headers: retryHeaders,
          body: formFields,
        );
      }
    }

    return response;
  }

  /// (NEW) DELETE 요청 메서드
  /// [body]가 null이 아니면 JSON 인코딩해서 보냄
  Future<http.Response> deleteRequest(String url, {Map<String, dynamic>? body}) async {
    final authState = _ref.read(authNotifierProvider);
    final token = authState.accessToken;

    if (token == null) {
      return http.Response('No access token', 401);
    }

    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    // DELETE 요청 본문 (body 있을 경우 JSON)
    final encodedBody = body != null ? jsonEncode(body) : null;

    var response = await http.delete(
      Uri.parse(url),
      headers: headers,
      body: encodedBody,
    );

    if (response.statusCode == 401) {
      // 401이면 토큰 재발급
      await _ref.read(authNotifierProvider.notifier).refreshAccessToken();

      final newToken = _ref.read(authNotifierProvider).accessToken;
      if (newToken != null) {
        final retryHeaders = {
          'Authorization': 'Bearer $newToken',
          'Content-Type': 'application/json',
        };
        response = await http.delete(
          Uri.parse(url),
          headers: retryHeaders,
          body: encodedBody,
        );
      }
    }

    return response;
  }
}
