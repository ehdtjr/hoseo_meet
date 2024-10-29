import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config.dart';
import 'authme_service.dart';
import '../chat/socket_message_service.dart';
import '../../firebase/create_token.dart'; // FCM 토큰 발급 함수를 import

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

      // 소켓 연결을 로그인 후에 한번만 실행
      _socketMessageService = SocketMessageService(_accessToken!);
      await _socketMessageService.connectWebSocket();

      // 로그인 성공 시 FCM 토큰 발급
      String? fcmToken = await TokenManager.createToken(); // FCM 토큰 발급 호출

      // FCM 토큰이 정상적으로 발급되었는지 확인
      if (fcmToken != null) {
        print("로그인 후 FCM 토큰: $fcmToken");
      } else {
        print("FCM 토큰 발급 실패 또는 null 반환");
      }
    }

    return response;
  }

  // 소켓 메시지 스트림 접근을 위한 메서드
  Stream<Map<String, dynamic>> get messageStream => _socketMessageService.messageStream;

  // SocketMessageService 인스턴스를 외부에서 접근할 수 있도록 메서드 추가
  SocketMessageService get socketMessageService => _socketMessageService;

  String? get accessToken => _accessToken;

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _socketMessageService.closeWebSocket(); // WebSocket 종료
  }
}
