import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/widgets.dart'; // Flutter 엔진 초기화

import 'api/send_token_service.dart'; // SendTokenService (AuthHttpClient 기반)
import '../../commons/network/auth_http_client_provider.dart'; // authHttpClientProvider
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TokenManager {
  static const String _tokenKey = 'fcm_token';

  // FCM 토큰 발급 및 저장
  // ref 파라미터를 받아, Riverpod Provider에서 AuthHttpClient를 획득
  static Future<String?> createToken(WidgetRef ref) async {
    try {
      // (1) Flutter 엔진 초기화
      WidgetsFlutterBinding.ensureInitialized();

      // (2) 로컬에 기존 토큰이 있나 확인
      final prefs = await SharedPreferences.getInstance();
      final existingToken = prefs.getString(_tokenKey);

      if (existingToken != null) {
        print("기존 FCM 토큰 사용: $existingToken");
        return existingToken;
      }

      // (3) FirebaseMessaging 인스턴스 생성 + 새 토큰 요청
      final messaging = FirebaseMessaging.instance;
      final newToken = await messaging.getToken();

      if (newToken != null) {
        print("FCM 토큰 발급 성공: $newToken");

        // (4) Riverpod으로부터 AuthHttpClient 획득 + SendTokenService 생성
        final client = ref.read(authHttpClientProvider);
        final sendTokenService = SendTokenService(client);

        // (5) 서버로 FCM 토큰 전송
        final response = await sendTokenService.sendToken(newToken);
        if (response.statusCode == 200) {
          // 전송 성공 시 로컬 저장
          await prefs.setString(_tokenKey, newToken);
          print("FCM 토큰이 서버로 전송되었고, 로컬 저장소에 저장되었습니다.");
        } else {
          print("서버로 FCM 토큰 전송 실패: ${response.statusCode}");
        }

        return newToken;
      } else {
        print("FCM 토큰 발급 실패");
        return null;
      }
    } catch (e) {
      print("FCM 토큰 발급 중 오류 발생: $e");
      return null;
    }
  }

  // 로컬 저장소에 저장된 토큰 삭제
  static Future<void> deleteToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    print("로컬 저장소의 FCM 토큰이 삭제되었습니다.");
  }
}
