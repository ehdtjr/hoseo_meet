import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config.dart'; // config 파일 import

class AuthService with WidgetsBindingObserver {
  String? _accessToken;
  final String loginEndpoint = '${AppConfig.baseUrl}/auth/jwt/login?lifetime_seconds=3600';  // loginEndpoint 추가

  static final AuthService _instance = AuthService._internal();  // 싱글톤 인스턴스

  factory AuthService() {
    return _instance;
  }

  AuthService._internal() {
    // 앱 라이프사이클을 감시하는 옵저버 추가
    WidgetsBinding.instance.addObserver(this);
  }

  // 앱이 백그라운드로 갈 때 호출
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // 앱이 백그라운드로 갈 때 토큰 삭제
      _accessToken = null;
    }
  }

  // 로그인 요청 함수
  Future<http.Response> loginUser({
    required String username,
    required String password,
  }) async {
    // 요청할 데이터를 URL-encoded 형식으로 만듭니다.
    final Map<String, String> requestData = {
      'grant_type': 'password',
      'username': username,
      'password': password,
      'scope': '',
      'client_id': 'string',
      'client_secret': 'string',
    };

    // POST 요청을 보냅니다.
    final response = await http.post(
      Uri.parse(loginEndpoint),  // loginEndpoint 사용
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: requestData,
    );

    // 성공 시 토큰 저장
    if (response.statusCode == 200) {
      final responseBody = jsonDecode(response.body);
      _accessToken = responseBody['access_token'];  // 토큰 저장
    }

    return response;
  }

  // 토큰 가져오기
  String? get accessToken => _accessToken;

  // 옵저버 제거
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}
