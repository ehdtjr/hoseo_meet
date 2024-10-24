import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config.dart'; // AppConfig import
import '../login/login_service.dart'; // AuthService import

class MessageReadService {
  final String readMessageEndpoint = '${AppConfig.baseUrl}/messages/flags/stream';
  final AuthService _authService;

  MessageReadService(this._authService);

  // 기존 메시지 읽음 처리 메서드
  Future<void> markMessagesAsRead({
    required int streamId,
    int numBefore = 0,
    int numAfter = 0,
  }) async {
    String? token = _authService.accessToken;

    if (token == null) {
      throw Exception('로그인 토큰이 없습니다. 로그인이 필요합니다.');
    }

    final headers = {
      'accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final body = jsonEncode({
      "anchor": "first_unread",
      "stream_id": streamId,
      "num_before": numBefore,
      "num_after": numAfter
    });

    print('POST 요청을 보냅니다:');
    print('Endpoint: $readMessageEndpoint');
    print('Headers: $headers');
    print('Body: $body');

    final response = await http.post(
      Uri.parse(readMessageEndpoint),
      headers: headers,
      body: body,
    );

    if (response.statusCode == 200) {
      print('메시지 읽음 처리 성공');
      print('응답 데이터: ${response.body}');
    } else {
      print('메시지 읽음 처리에 실패했습니다: ${response.statusCode}');
      print('응답 데이터: ${response.body}');
    }
  }

  // 신규 메시지에 대한 읽음 처리 (웹소켓 메시지 수신 시 호출)
  Future<void> markNewestMessageAsRead({
    required int streamId,
  }) async {
    String? token = _authService.accessToken;

    if (token == null) {
      throw Exception('로그인 토큰이 없습니다. 로그인이 필요합니다.');
    }

    final headers = {
      'accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final body = jsonEncode({
      "anchor": "newest",
      "stream_id": streamId,
      "num_before": 0,
      "num_after": 0
    });

    print('POST 요청을 보냅니다:');
    print('Endpoint: $readMessageEndpoint');
    print('Headers: $headers');
    print('Body: $body');

    final response = await http.post(
      Uri.parse(readMessageEndpoint),
      headers: headers,
      body: body,
    );

    if (response.statusCode == 200) {
      print('신규 메시지 읽음 처리 성공');
      print('응답 데이터: ${response.body}');
    } else {
      print('신규 메시지 읽음 처리에 실패했습니다: ${response.statusCode}');
      print('응답 데이터: ${response.body}');
    }
  }
}
