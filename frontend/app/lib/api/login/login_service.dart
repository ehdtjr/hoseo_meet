import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../config.dart';
import '../chat/socket_message_service.dart';
import 'authme_service.dart';

class AuthService with WidgetsBindingObserver {
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
  SocketMessageService? _socketMessageService;

  static const _secureStorage = FlutterSecureStorage(); // flutter_secure_storage

  final String _loginEndpoint = '${AppConfig.baseUrl}/auth/login?lifetime_seconds=3600';
  final String _refreshEndpoint = '${AppConfig.baseUrl}/auth/refresh';

  // -------------------------------
  // init() -> SplashScreen에서 호출하여 토큰 복원
  // -------------------------------
  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    await restoreRefreshToken(); // 기존에 private이었던 메서드를 public으로 변경 & await
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // 백그라운드 -> 소켓 닫기
      _socketMessageService?.closeWebSocket();
    } else if (state == AppLifecycleState.resumed) {
      // 포어그라운드 -> 토큰 있으면 소켓 연결
      if (_accessToken != null) {
        _initializeSocketService();
      }
    }
  }

  // -------------------------------
  // (A) Refresh Token 복원 (public)
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

      // 소켓 연결
      await _initializeSocketService();
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
        await _initializeSocketService();
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
  // (E) 소켓 연결
  // -------------------------------
  Future<void> _initializeSocketService() async {
    if (_accessToken != null && _socketMessageService == null) {
      _socketMessageService = SocketMessageService(_accessToken!);
      await _socketMessageService?.connectWebSocket();
      print('[AuthService] WebSocket connected');
    } else if (_accessToken != null && _socketMessageService != null) {
      // 이미 소켓 객체 존재 -> 필요 시 재연결
      print('[AuthService] SocketMessageService already exists');
    }
  }

  // -------------------------------
  // (F) WebSocket 메세지 스트림
  // -------------------------------
  Stream<Map<String, dynamic>> get messageStream =>
      _socketMessageService?.messageStream ?? Stream.empty();

  // -------------------------------
  // (G) Getter
  // -------------------------------
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  // -------------------------------
  // (H) 종료
  // -------------------------------
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _socketMessageService?.closeWebSocket();
  }
}
