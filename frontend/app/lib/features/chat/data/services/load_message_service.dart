import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../../api/login/login_service.dart';
import '../../../../config.dart';
import '../models/chat_message.dart';
// (A) 모델 임포트

class LoadMessageService {
  final String messageEndpoint = '${AppConfig.baseUrl}/messages/stream';
  final AuthService _authService;

  LoadMessageService(this._authService);

  /// 메시지를 불러오는 함수
  /// - [anchor]: 기본 'first_unread' 이지만, 특정 messageId 등으로 설정 가능
  /// - [numBefore], [numAfter]: 불러올 이전/이후 메시지 개수
  Future<List<ChatMessage>> loadMessages({
    required int streamId,
    String anchor = 'first_unread', // 처음 진입 시, 안 읽은 메시지를 중심으로 로딩 가능
    int numBefore = 10,
    int numAfter = 30,
  }) async {
    // (B) Uri 사용을 권장
    final uri = Uri.parse(messageEndpoint).replace(queryParameters: {
      'stream_id': streamId.toString(),
      'anchor': anchor,
      'num_before': numBefore.toString(),
      'num_after': numAfter.toString(),
    });

    // AuthService 내부에 getRequest(Uri) 가 있다고 가정 (401 시 자동 리프레시 처리)
    final http.Response response = await _authService.getRequest(uri.toString());

    if (response.statusCode == 200) {
      final decoded = jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as List<dynamic>;

      // (C) 각 항목을 ChatMessage.fromJson()으로 변환 → List<ChatMessage>
      return decoded
          .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception(
        '메시지를 불러오는데 실패했습니다: ${response.statusCode}, 응답: ${response.body}',
      );
    }
  }
}
