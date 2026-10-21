import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config.dart';
import '../login/authme_service.dart';
import '../chat/socket_message_service.dart';

class AuthService with WidgetsBindingObserver {
  String? _accessToken;
  final String loginEndpoint = '${AppConfig.baseUrl}/auth/jwt/login?lifetime_seconds=3600';
  late final SocketMessageService _socketMessageService;

  static final AuthService _instance = AuthService._internal();

  factory AuthService() {
    return _instance;
  }

  AuthService._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _accessToken = null;
      _socketMessageService.closeWebSocket(); // WebSocket 종료
    }
  }

  Future<http.Response> loginUser({
    required String username,
    required String password,
  }) async {
    final Map<String, String> requestData = {
      'grant_type': 'password',
      'username': username,
      'password': password,
      'scope': '',
      'client_id': 'string',
      'client_secret': 'string',
    };

    final response = await http.post(
      Uri.parse(loginEndpoint),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: requestData,
    );

    if (response.statusCode == 200) {
      final responseBody = jsonDecode(response.body);
      _accessToken = responseBody['access_token'];

      final authMeService = AuthMeService(_accessToken!);
      await authMeService.fetchAndStoreUserId();

      _socketMessageService = SocketMessageService(_accessToken!);
      await _socketMessageService.connectWebSocket();
    }

    return response;
  }

  String? get accessToken => _accessToken;

  // 부모 클래스의 dispose 호출을 제거합니다.
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}
