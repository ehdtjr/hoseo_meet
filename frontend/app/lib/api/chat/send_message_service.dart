import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config.dart'; // config 파일 import
import '../login/login_service.dart'; // AuthService import

class SendMessageService {
  final String sendMessageEndpoint = '${AppConfig.baseUrl}/messages/send/stream/';
  final AuthService _authService;

  SendMessageService(this._authService);

  // 메시지를 보내는 함수
  Future<void> sendMessage({
    required int streamId,
    required String messageContent,
  }) async {
    // 저장된 토큰을 가져옵니다.
    String? token = _authService.accessToken;

    if (token == null) {
      throw Exception('로그인 토큰이 없습니다. 로그인이 필요합니다.');
    }

    // 요청 헤더 설정 (Bearer 토큰 추가)
    final headers = {
      'accept': 'application/json',
      'Content-Type': 'application/x-www-form-urlencoded',
      'Authorization': 'Bearer $token', // Bearer 토큰 추가
    };

    // 요청 바디 설정 (message_content 포함)
    final body = {
      'message_content': messageContent,
    };

    // POST 요청 보내기
    final response = await http.post(
      Uri.parse('$sendMessageEndpoint$streamId?lifetime_seconds=3600'),
      headers: headers,
      body: body, // URL 인코딩된 데이터 전송
    );

    if (response.statusCode == 200) {
      print('메시지 전송 성공: ${response.body}');
    } else {
      throw Exception('메시지 전송에 실패했습니다: ${response.body}');
    }
  }
}
