import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../config.dart';
import 'authme_service.dart';

class AuthService {
  // -------------------------------
  // 싱글턴 패턴
  // -------------------------------
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // -------------------------------
  // 필드
  // -------------------------------
  String? _accessToken;
  String? _refreshToken;

  static const _secureStorage = FlutterSecureStorage(); // flutter_secure_storage

  final String _loginEndpoint = '${AppConfig.baseUrl}/auth/login?lifetime_seconds=3600';
  final String _refreshEndpoint = '${AppConfig.baseUrl}/auth/refresh';

  // -------------------------------
  // init() -> SplashScreen에서 호출하여 토큰 복원
  // -------------------------------
  Future<void> init() async {
    await restoreRefreshToken();
  }

  // -------------------------------
  // (A) Refresh Token 복원
  // -------------------------------
  Future<void> restoreRefreshToken() async {
    try {
      final token = await _secureStorage.read(key: 'refresh_token');
      if (token != null) {
        _refreshToken = token;
        print('[AuthService] Refresh Token restored: $_refreshToken');
      } else {
        print('[AuthService] No refresh token found in storage');
      }
    } catch (e) {
      print('[AuthService] Failed to read refresh token: $e');
    }
  }

  // -------------------------------
  // (B) 로그인 로직
  // -------------------------------
  Future<http.Response> loginUser({
    required String username,
    required String password,
  }) async {
    print('[AuthService] loginUser() - username=$username');
    final requestData = {
      'grant_type': 'password',
      'username': username,
      'password': password,
      'scope': '',
      'client_id': 'string',
      'client_secret': 'string',
    };

    final response = await http.post(
      Uri.parse(_loginEndpoint),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: requestData,
    );

    print('[AuthService] loginUser() -> code=${response.statusCode}');
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      _accessToken = body['access_token'];
      _refreshToken = body['refresh_token'];

      print('[AuthService] parsed tokens: access=$_accessToken, refresh=$_refreshToken');

      // refresh 토큰 저장
      if (_refreshToken != null) {
        await _saveRefreshToken(_refreshToken!);
      }

      // 유저 정보 조회
      final authMeService = AuthMeService(_accessToken!);
      await authMeService.fetchAndStoreUserId();
    } else {
      print('[AuthService] loginUser failed: ${response.body}');
    }

    return response;
  }

  // -------------------------------
  // (C) Refresh Token 재발급 (자동로그인)
  // -------------------------------
  Future<bool> refreshAccessToken() async {
    if (_refreshToken == null) {
      print('[AuthService] refreshAccessToken() -> no refresh token available');
      return false;
    }

    try {
      print('[AuthService] Attempting to refresh token=$_refreshToken');
      final response = await http.post(
        Uri.parse(_refreshEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"refresh_token": _refreshToken}),
      );
      print('[AuthService] refresh code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        final newRefresh = data['refresh_token'];
        if (newRefresh != null) {
          _refreshToken = newRefresh;
          await _saveRefreshToken(newRefresh);
        }
        print('[AuthService] Access token refreshed successfully: $_accessToken');
        return true;
      } else {
        print('[AuthService] refresh failed: ${response.body}');
        return false;
      }
    } catch (e) {
      print('[AuthService] Exception in refreshAccessToken: $e');
      return false;
    }
  }

  // -------------------------------
  // (D) Refresh Token 저장
  // -------------------------------
  Future<void> _saveRefreshToken(String token) async {
    try {
      print('[AuthService] _saveRefreshToken called with $token');
      await _secureStorage.write(key: 'refresh_token', value: token);
      print('[AuthService] Refresh Token saved');
    } catch (e) {
      print('[AuthService] Failed to save refresh token: $e');
    }
  }

  // -------------------------------
  // (E) 자동 토큰 갱신을 위한 공통 요청 메서드 예시
  // -------------------------------

  /// GET 요청 시도 -> 401이면 refresh 후 재시도
  Future<http.Response> getRequest(String url) async {
    // 1) 엑세스 토큰을 헤더에 넣어서 GET
    final headers = {
      'Authorization': 'Bearer $_accessToken',
      'Content-Type': 'application/json',
    };

    final response = await http.get(Uri.parse(url), headers: headers);

    // 2) 401(Unauthorized)라면 -> 토큰 재발급 시도 후 재요청
    if (response.statusCode == 401) {
      final refreshed = await refreshAccessToken();
      if (refreshed) {
        // 토큰 재발급 성공 -> 새 토큰으로 재시도
        final retryHeaders = {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        };
        return await http.get(Uri.parse(url), headers: retryHeaders);
      }
    }

    return response;
  }

  /// POST 요청 시도 -> 401이면 refresh 후 재시도
  Future<http.Response> postRequest(String url, Map<String, dynamic> body) async {
    final headers = {
      'Authorization': 'Bearer $_accessToken',
      'Content-Type': 'application/json',
    };

    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 401) {
      final refreshed = await refreshAccessToken();
      if (refreshed) {
        final retryHeaders = {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        };
        return await http.post(
          Uri.parse(url),
          headers: retryHeaders,
          body: jsonEncode(body),
        );
      }
    }

    return response;
  }

  Future<http.Response> postRequestFormUrlEncoded(String url, Map<String, String> formFields) async {
    final headers = {
      'Authorization': 'Bearer $_accessToken',
      'Content-Type': 'application/x-www-form-urlencoded',
    };

    // 1) 첫 번째 요청
    var response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: formFields, // formFields: Map<String, String>
    );

    // 2) 401 -> 토큰 리프레시 + 재시도
    if (response.statusCode == 401) {
      final refreshed = await refreshAccessToken();
      if (refreshed) {
        final retryHeaders = {
          'Authorization': 'Bearer $_accessToken',
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


  // -------------------------------
  // (F) Getter
  // -------------------------------
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  // -------------------------------
  // (G) 종료
  // -------------------------------
  void dispose() {
    print('[AuthService] dispose() called');
  }
}
