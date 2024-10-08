import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config.dart'; // config 파일 import
import '../login/login_service.dart'; // AuthService import

class JoinRoomService {
  final String joinRoomEndpoint = '${AppConfig.baseUrl}/users/me/subscriptions?lifetime_seconds=3600';
  final AuthService _authService;

  JoinRoomService(this._authService);

  Future<http.Response> joinRoom({
    required int streamId,
  }) async {
    // 저장된 토큰을 가져옵니다.
    String? token = _authService.accessToken;

    if (token == null) {
      throw Exception('로그인 토큰이 없습니다. 로그인이 필요합니다.');
    }

    // 요청 헤더 설정 (Bearer 토큰 추가)
    final headers = {
      'accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token', // Bearer 토큰 추가
    };

    // 요청 바디 설정 (stream_id 포함)
    final body = jsonEncode({
      'stream_id': streamId,
    });

    // 콘솔에 요청 정보 로그 출력
    print('POST 요청을 보냅니다:');
    print('URL: $joinRoomEndpoint');
    print('헤더: $headers');
    print('바디: $body');

    // POST 요청 보내기 (헤더와 바디 포함)
    final response = await http.post(
      Uri.parse(joinRoomEndpoint),
      headers: headers,
      body: body,
    );

    return response;
  }
}
