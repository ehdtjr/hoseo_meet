import 'package:http/http.dart' as http;
import '../../../../commons/network/auth_http_client.dart'; // AuthHttpClient import
import '../../../../config.dart';

class MessageReadService {
  final String readMessageEndpoint = '${AppConfig.baseUrl}/messages/flags/stream';
  final AuthHttpClient _client; // AuthHttpClient를 주입

  MessageReadService(this._client);

  /// (A) 기존 메시지 읽음 처리
  Future<void> markMessagesAsRead({
    required int streamId,
    String anchor = 'first_unread',
    int numBefore = 0,
    int numAfter = 0,
  }) async {
    // (1) 요청 바디
    final body = {
      "anchor": anchor,
      "stream_id": streamId,
      "num_before": numBefore,
      "num_after": numAfter,
    };

    print('[MessageReadService] markMessagesAsRead -> body=$body');

    // (2) AuthHttpClient 사용
    final http.Response response = await _client.postRequest(
      readMessageEndpoint,
      body,
    );

    // (3) 응답 처리
    if (response.statusCode == 200) {
      print('메시지 읽음 처리 성공');
      print('응답 데이터: ${response.body}');
    } else {
      print('메시지 읽음 처리에 실패했습니다: ${response.statusCode}');
      print('응답 데이터: ${response.body}');
    }
  }

  /// (B) 신규 메시지에 대한 읽음 처리 (웹소켓 메시지 수신 시 호출)
  Future<void> markNewestMessageAsRead({required int streamId}) async {
    // (1) 요청 바디
    final body = {
      "anchor": "newest",
      "stream_id": streamId,
      "num_before": 0,
      "num_after": 0,
    };

    print('[MessageReadService] markNewestMessageAsRead -> body=$body');

    // (2) AuthHttpClient 사용
    final http.Response response = await _client.postRequest(
      readMessageEndpoint,
      body,
    );

    // (3) 응답 처리
    if (response.statusCode == 200) {
      print('신규 메시지 읽음 처리 성공');
      print('응답 데이터: ${response.body}');
    } else {
      print('신규 메시지 읽음 처리 실패: ${response.statusCode}');
      print('응답 데이터: ${response.body}');
    }
  }
}
