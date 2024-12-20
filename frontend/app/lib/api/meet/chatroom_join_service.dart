import 'dart:convert';
import 'package:http/http.dart' as http;
import '../login/login_service.dart';
import '../../config.dart';

class ChatroomJoinService {
  final String joinChatroomEndpoint = '${AppConfig.baseUrl}/meet_post/subscribe';
  final AuthService _authService = AuthService(); // AuthService 싱글톤 인스턴스 사용

  Future<void> joinChatroom({
    required int postId,
    int lifetimeSeconds = 3600,
  }) async {
    String? accessToken = _authService.accessToken;

    if (accessToken == null) {
      print('Error: No valid access token found.');
      throw Exception('유효한 토큰이 없습니다. 로그인 상태를 확인하세요.');
    }

    final url = Uri.parse('$joinChatroomEndpoint/$postId?lifetime_seconds=$lifetimeSeconds');
    print('Requesting to join chatroom with postId: $postId');

    try {
      final response = await http.post(
        url,
        headers: {
          'accept': 'application/json',
          'Authorization': 'Bearer $accessToken', // Bearer 토큰을 헤더에 추가
        },
      );

      final responseBody = utf8.decode(response.bodyBytes); // UTF-8로 디코딩하여 응답 본문을 얻음

      if (response.statusCode == 200) {
        print('채팅방 참여 성공: $responseBody');
      } else {
        print('채팅방 참여 실패: StatusCode: ${response.statusCode}, Body: $responseBody');
        throw Exception('채팅방 참여 실패: ${response.statusCode} - $responseBody');
      }
    } catch (error) {
      print('Error occurred while joining chatroom: $error');
      rethrow; // rethrow the error to handle it outside if necessary
    }
  }
}
