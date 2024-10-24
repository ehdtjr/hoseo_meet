import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config.dart'; // config 파일 import

class AuthMeService {
  final String _accessToken;  // 로그인 시 저장된 토큰
  final String authMeEndpoint = '${AppConfig.baseUrl}/auth/me?lifetime_seconds=3600'; // 유저 정보 API 엔드포인트
  int? _userId;  // 유저 ID를 저장할 변수

  AuthMeService(this._accessToken);

  // 유저 정보를 가져와서 유저 ID를 메모리에 저장하는 함수
  Future<void> fetchAndStoreUserId() async {
    // 요청 헤더 설정 (Bearer 토큰 추가)
    final headers = {
      'accept': 'application/json',
      'Authorization': 'Bearer $_accessToken', // Bearer 토큰 추가
    };

    // GET 요청 보내기
    final response = await http.get(
      Uri.parse(authMeEndpoint),
      headers: headers,
    );

    if (response.statusCode == 200) {
      // 응답을 JSON으로 디코딩하여 유저 ID 저장
      final responseBody = jsonDecode(response.body);
      _userId = responseBody['id'];
      print('유저 ID 저장 성공: $_userId');
    } else {
      throw Exception('유저 정보를 불러오는데 실패했습니다: ${response.statusCode}');
    }
  }

  // 유저 ID 가져오기
  int? get userId => _userId;
}
