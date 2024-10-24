import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config.dart'; // config 파일 import
import '../login/login_service.dart'; // 로그인 서비스 파일 import

class LoadMessageService {
  final String messageEndpoint = '${AppConfig.baseUrl}/messages/stream';
  final AuthService _authService;

  LoadMessageService(this._authService);

  // 메시지를 불러오는 함수
  Future<List<dynamic>> loadMessages(int streamId) async {
    // 저장된 토큰을 가져옵니다.
    String? token = _authService.accessToken;

    if (token == null) {
      throw Exception('로그인 토큰이 없습니다. 로그인이 필요합니다.');
    }

    // 요청 헤더 설정 (Bearer 토큰 추가)
    final headers = {
      'accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    // 요청 URL 설정
    final url =
        '$messageEndpoint?stream_id=$streamId&anchor=first_unread&num_before=100&num_after=100';

    // GET 요청 보내기
    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );

    if (response.statusCode == 200) {
      // 응답을 UTF-8로 디코딩
      final responseData = utf8.decode(response.bodyBytes);
      final List<dynamic> decodedData = jsonDecode(responseData);

      return decodedData;
    } else {
      throw Exception('메시지를 불러오는데 실패했습니다: ${response.statusCode}');
    }
  }
}
