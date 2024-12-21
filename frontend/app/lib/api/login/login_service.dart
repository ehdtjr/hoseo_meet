import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config.dart';
import 'authme_service.dart';
import '../chat/socket_message_service.dart';
import '../../firebase/create_token.dart';

class AuthService with WidgetsBindingObserver {
  String? _accessToken;
  final String loginEndpoint = '${AppConfig.baseUrl}/auth/login?lifetime_seconds=3600';
  SocketMessageService? _socketMessageService;

  static final AuthService _instance = AuthService._internal();

  factory AuthService() {
    return _instance;
  }

  AuthService._internal() {
    WidgetsBinding.instance.addObserver(this);
    _restoreToken(); // 앱 시작 시 토큰을 복원
  }

  // 앱 시작 시 저장된 토큰 복원
  Future<void> _restoreToken() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');

    // 토큰이 존재할 경우 로그인 상태로 유지하지만 소켓 연결은 하지 않음
    if (_accessToken != null) {
      print('Token restored from local storage, but socket connection will only initialize on login.');
    }
  }

  // 소켓 서비스 초기화 메서드 (로그인 성공 시에만 호출)
  Future<void> _initializeSocketService() async {
    if (_accessToken != null && _socketMessageService == null) {
      _socketMessageService = SocketMessageService(_accessToken!);
      await _socketMessageService?.connectWebSocket();
    }
  }

  // 백그라운드로 이동 시 토큰을 저장하고 소켓 종료
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _saveToken(); // 앱이 백그라운드로 이동할 때 토큰을 저장
      _socketMessageService?.closeWebSocket(); // WebSocket 종료
    } else if (state == AppLifecycleState.resumed && _accessToken != null) {
      // 앱이 다시 포그라운드로 돌아오면 토큰이 있을 때만 WebSocket 재연결
      _initializeSocketService(); // 로그인 상태일 때만 WebSocket을 재연결
    }
  }

  Future<void> _saveToken() async {
    final prefs = await SharedPreferences.getInstance();
    if (_accessToken != null) {
      await prefs.setString('access_token', _accessToken!);
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

      // 로그인 성공 시 토큰 저장
      _saveToken();

      final authMeService = AuthMeService(_accessToken!);
      await authMeService.fetchAndStoreUserId();

      // 로그인 성공 후 소켓 서비스 초기화 및 연결
      await _initializeSocketService();

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
  Stream<Map<String, dynamic>> get messageStream =>
      _socketMessageService?.messageStream ?? Stream.empty();

  // SocketMessageService 인스턴스를 외부에서 접근할 수 있도록 메서드 추가
  SocketMessageService? get socketMessageService => _socketMessageService;

  String? get accessToken => _accessToken;

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _socketMessageService?.closeWebSocket(); // WebSocket 종료
  }
}
