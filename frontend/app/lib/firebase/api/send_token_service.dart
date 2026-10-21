import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config.dart'; // AppConfig import (기본 URL이 여기에서 가져옵니다)
import '../../api/login/login_service.dart'; // AuthService import (액세스 토큰 가져오기)

class SendTokenService {
  final String _endpoint = '${AppConfig.baseUrl}/users/me/register/fcm-token?lifetime_seconds=3600';
  final AuthService _authService;

  SendTokenService(this._authService);

  // FCM 토큰을 서버에 전송하는 함수
  Future<http.Response> sendToken(String fcmToken) async {
    String? token = _authService.accessToken;


    // 릴리즈 배포할때 주석을 제거해야함
    // if (token == null) {
    //   throw Exception('액세스 토큰이 없습니다. 로그인이 필요합니다.');
    // }

    // 헤더 설정
    final headers = {
      'accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token', // 액세스 토큰을 헤더에 추가
    };

    // 요청 바디 설정
    final body = jsonEncode({
      'fcm_token': fcmToken,
    });

    try {
      // POST 요청을 보냅니다.
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: headers,
        body: body,
      );

      return response; // response 반환
    } catch (e) {
      print('FCM 토큰 전송 중 오류 발생: $e');
      rethrow; // 오류를 다시 던집니다.
    }
  }
}
