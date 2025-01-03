import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../../commons/network/auth_http_client.dart';
import '../../../../config.dart';
import '../models/chat_message.dart';

class LoadMessageService {
  final String messageEndpoint = '${AppConfig.baseUrl}/messages/stream';
  final AuthHttpClient _client; // AuthHttpClient를 주입

  LoadMessageService(this._client);

  /// 메시지를 불러오는 함수
  /// - [anchor]: 기본 'first_unread' 이지만, 특정 messageId 등으로 설정 가능
  /// - [numBefore], [numAfter]: 불러올 이전/이후 메시지 개수
  Future<List<ChatMessage>> loadMessages({
    required int streamId,
    String anchor = 'first_unread',
    int numBefore = 10,
    int numAfter = 30,
  }) async {
    // URI 구성
    final uri = Uri.parse(messageEndpoint).replace(queryParameters: {
      'stream_id': streamId.toString(),
      'anchor': anchor,
      'num_before': numBefore.toString(),
      'num_after': numAfter.toString(),
    });

    // AuthHttpClient를 통해 GET 요청
    final http.Response response = await _client.getRequest(uri.toString());

    if (response.statusCode == 200) {
      final decoded = jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as List<dynamic>;

      // 각 항목을 ChatMessage.fromJson()으로 변환 → List<ChatMessage>
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
