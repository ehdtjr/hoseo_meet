import 'dart:convert';
import 'package:http/http.dart' as http;
import '../login/login_service.dart';
import '../../config.dart';

class CreatePostService {
  final String createPostEndpoint = '${AppConfig.baseUrl}/meet_post/create?lifetime_seconds=3600';

  // AuthService 싱글톤 인스턴스 호출
  final AuthService _authService = AuthService();

  Future<void> createPost({
    required String title,
    required String type,
    required String content,
    required int maxPeople,
  }) async {
    // AuthService에서 토큰을 가져옵니다.
    String? accessToken = _authService.accessToken;

    if (accessToken == null) {
      throw Exception('유효한 토큰이 없습니다. 로그인 상태를 확인하세요.');
    }

    final response = await http.post(
      Uri.parse(createPostEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'accept': 'application/json',
        'Authorization': 'Bearer $accessToken', // 토큰을 헤더에 추가
      },
      body: jsonEncode({
        "title": title,
        "type": type,
        "content": content,
        "max_people": maxPeople,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      print('게시글 생성 성공');
    } else {
      throw Exception('게시글 생성 실패: ${response.body}');
    }
  }
}
