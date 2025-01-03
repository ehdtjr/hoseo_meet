import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../../commons/network/auth_http_client.dart';
import '../../../../config.dart';
import '../models/chat_room.dart';

class ChatRoomService {
  // 채팅방 목록 조회용 엔드포인트
  final String roomListEndpoint =
      '${AppConfig.baseUrl}/users/me/subscriptions?lifetime_seconds=3600';

  // 구독 취소(삭제)용 엔드포인트
  final String unsubscribeEndpoint =
      '${AppConfig.baseUrl}/users/me/subscriptions';

  final AuthHttpClient _client;

  // 생성자
  ChatRoomService(this._client);

  /// (1) 채팅방 목록 조회
  ///
  /// 성공 시 `List<ChatRoom>` 반환,
  /// 실패 시 Exception 발생
  Future<List<ChatRoom>> loadRoomList() async {
    final http.Response response = await _client.getRequest(roomListEndpoint);
    if (response.statusCode == 200) {
      final decodedResponse = utf8.decode(response.bodyBytes);
      final Map<String, dynamic> responseData = jsonDecode(decodedResponse);

      final List<dynamic> subs = responseData['subscriptions'] as List<dynamic>;
      final List<ChatRoom> chatRooms = subs.map((sub) {
        return ChatRoom.fromJson(sub as Map<String, dynamic>);
      }).toList();

      return chatRooms;
    } else {
      throw Exception(
        '채팅방 목록을 불러오는데 실패했습니다.\n'
            'statusCode: ${response.statusCode}\n'
            'body: ${response.body}',
      );
    }
  }

  /// (2) 채팅방 구독 해제 (DELETE)
  ///
  /// [streamId]가 구독 취소할 채팅방 ID.
  /// 서버가 2xx 응답이면 성공, 그 외엔 Exception 발생
  Future<void> unsubscribeRoom(int streamId) async {
    final Map<String, dynamic> requestBody = {
      'stream_id': streamId,
    };

    final http.Response response = await _client.deleteRequest(
      unsubscribeEndpoint,
      body: requestBody,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        '채팅방 구독 취소에 실패했습니다.\n'
            'statusCode: ${response.statusCode}\n'
            'body: ${response.body}',
      );
    }
    // 2xx 응답이면 성공
  }
}
