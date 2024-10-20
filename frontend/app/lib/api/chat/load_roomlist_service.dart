import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config.dart'; // config 파일 import
import '../login/login_service.dart'; // AuthService import

class LoadRoomListService {
  final String roomListEndpoint = '${AppConfig.baseUrl}/users/me/subscriptions?lifetime_seconds=3600';
  final AuthService _authService;

  LoadRoomListService(this._authService);

  // 채팅방 리스트를 불러오는 함수
  Future<List<dynamic>> loadRoomList() async {
    // 저장된 토큰을 가져옵니다.
    String? token = _authService.accessToken;

    if (token == null) {
      throw Exception('로그인 토큰이 없습니다. 로그인이 필요합니다.');
    }

    // 요청 헤더 설정 (Bearer 토큰 추가)
    final headers = {
      'accept': 'application/json',
      'Authorization': 'Bearer $token', // Bearer 토큰 추가
    };

    // GET 요청 보내기
    final response = await http.get(
      Uri.parse(roomListEndpoint),
      headers: headers,
    );

    if (response.statusCode == 200) {
      // 응답을 JSON으로 디코딩
      final Map<String, dynamic> responseData = jsonDecode(response.body);

      // 'subscriptions' 리스트만 추출하여 반환
      return responseData['subscriptions'];
    } else {
      throw Exception('채팅방 목록을 불러오는데 실패했습니다: ${response.statusCode}');
    }
  }
}
