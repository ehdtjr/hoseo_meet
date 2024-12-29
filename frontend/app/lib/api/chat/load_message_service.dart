import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config.dart';
import '../login/login_service.dart'; // AuthService

class LoadMessageService {
  final String messageEndpoint = '${AppConfig.baseUrl}/messages/stream';
  final AuthService _authService;

  LoadMessageService(this._authService);

  /// 메시지를 불러오는 함수
  /// - [anchor]: 기본 'first_unread' 이지만, 특정 messageId 등으로 설정 가능
  /// - [numBefore], [numAfter]: 불러올 이전/이후 메시지 개수
  Future<List<dynamic>> loadMessages({
    required int streamId,
    String anchor = 'first_unread', // 처음 진입 시, 안 읽은 메시지를 중심으로 로딩 가능
    int numBefore = 10,
    int numAfter = 30,
  }) async {
    final url = '$messageEndpoint'
        '?stream_id=$streamId'
        '&anchor=$anchor'
        '&num_before=$numBefore'
        '&num_after=$numAfter';

    // AuthService 내부에 getRequest가 있다고 가정 (401 시 자동 리프레시 처리)
    final http.Response response = await _authService.getRequest(url);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(
        utf8.decode(response.bodyBytes),
      );
      // 서버가 List 형태를 반환한다고 가정
      return decoded as List<dynamic>;
    } else {
      throw Exception(
        '메시지를 불러오는데 실패했습니다: ${response.statusCode}, 응답: ${response.body}',
      );
    }
  }
}
