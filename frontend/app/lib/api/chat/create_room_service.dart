import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config.dart'; // config 파일 import
import '../login/login_service.dart'; // 로그인 서비스 파일 import

class CreateRoomService {
  final String createRoomEndpoint = '${AppConfig.baseUrl}/stream/create?lifetime_seconds=3600';
  final AuthService _authService;

  CreateRoomService(this._authService);

  Future<http.Response> createRoom({
    required String roomName,
    required String roomType, // 타입 추가
  }) async {
    // 저장된 토큰을 가져옵니다.
    String? token = _authService.accessToken;

    if (token == null) {
      throw Exception('로그인 토큰이 없습니다. 로그인이 필요합니다.');
    }

    // 요청 헤더 설정 (Bearer 토큰 추가)
    final headers = {
      'accept': 'application/json',
      'Content-Type': 'application/json; charset=UTF-8', // UTF-8 인코딩 추가
      'Authorization': 'Bearer $token', // Bearer 토큰 추가
    };

    // 요청 바디 설정 (roomName과 roomType을 포함)
    final body = jsonEncode({
      'name': roomName,
      'type': roomType, // 타입 추가
    });

    // POST 요청 보내기 (헤더와 바디 포함)
    final response = await http.post(
      Uri.parse(createRoomEndpoint),
      headers: headers,
      body: body, // UTF-8로 인코딩된 바디 전송
    );

    return response;
  }
}
