import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/widgets.dart'; // Flutter 엔진 초기화
import 'api/send_token_service.dart'; // SendTokenService import
import '../../api/login/login_service.dart'; // AuthService import

class TokenManager {
  static const String _tokenKey = 'fcm_token';

  // 토큰 발급 및 저장
  static Future<String?> createToken() async {
    try {
      // Flutter 엔진 초기화 (필요할 경우 추가)
      WidgetsFlutterBinding.ensureInitialized();

      // 로컬 저장소에서 기존 토큰 확인
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? existingToken = prefs.getString(_tokenKey);

      // 기존 토큰이 존재하면 재발급하지 않음
      if (existingToken != null) {
        print("기존 FCM 토큰 사용: $existingToken");
        return existingToken;
      }

      // FirebaseMessaging 인스턴스 생성 및 토큰 요청
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      String? newToken = await messaging.getToken();

      if (newToken != null) {
        print("FCM 토큰 발급 성공: $newToken");

        // FCM 토큰 발급 성공 시 서버로 전송 (AuthService에서 토큰을 받아와야 함)
        AuthService authService = AuthService(); // AuthService 인스턴스 생성
        SendTokenService sendTokenService = SendTokenService(authService);

        // SendTokenService를 사용하여 서버로 FCM 토큰 전송 후 응답 확인
        final response = await sendTokenService.sendToken(newToken);

        if (response.statusCode == 200) {
          // 응답이 성공일 경우 로컬 저장소에 토큰 저장
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
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    print("로컬 저장소의 FCM 토큰이 삭제되었습니다.");
  }
}
