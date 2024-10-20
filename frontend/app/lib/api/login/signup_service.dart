import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config.dart'; // config 파일 import

class AuthService {
  final String registerEndpoint = '${AppConfig.baseUrl}/auth/register'; // baseUrl + 엔드포인트

  // 회원가입 요청 함수
  Future<http.Response> registerUser({
    required String email,
    required String password,
    required String name,
    required String gender,
  }) async {
    // 현재 날짜를 생성합니다.
    final DateTime now = DateTime.now();
    final String createdAt = now.toIso8601String();

    // 요청할 데이터를 만듭니다.
    final Map<String, dynamic> requestData = {
      "email": email,
      "password": password,
      "is_active": true,
      "is_superuser": false,  //제거해야할듯?
      "is_verified": false,
      "name": name,
      "gender": gender,
      "profile": "", // 프로필은 기본값으로 비워둡니다.
      "created_at": createdAt,
    };

    // POST 요청을 보냅니다.
    final response = await http.post(
      Uri.parse(registerEndpoint),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(requestData),
    );

    // 응답을 반환합니다.
    return response;
  }
}

