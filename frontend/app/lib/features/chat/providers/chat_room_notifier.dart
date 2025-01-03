import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/chat_room.dart';
import '../data/services/chat_room_service.dart'; // ChatRoomService import
import 'package:intl/intl.dart';                 // 날짜 파싱 시 필요(선택)

class ChatRoomNotifier extends StateNotifier<List<ChatRoom>> {
  final ChatRoomService service;

  ChatRoomNotifier(this.service) : super([]);

  /// (1) 채팅방 목록 불러오기
  Future<void> fetchRooms() async {
    try {
      final rooms = await service.loadRoomList(); // Service에서 목록 불러오기

      // (A) rooms를 "마지막 메시지 시간" 기준으로 내림차순 정렬
      rooms.sort((a, b) {
        // a.time, b.time: ISO 8601(또는 다른 형식)일 가능성
        // 1) 문자열이 비었으면 가장 뒤로
        if (a.time.isEmpty && b.time.isNotEmpty) {
          return 1; // a 뒤로
        } else if (b.time.isEmpty && a.time.isNotEmpty) {
          return -1; // b 뒤로
        } else if (a.time.isEmpty && b.time.isEmpty) {
          return 0;
        }

        // 2) 문자열이 있으면 DateTime.parse(...) → 비교
        final dateA = parseToDateTime(a.time);
        final dateB = parseToDateTime(b.time);

        // 3) 내림차순: b가 더 최신이면 양수 리턴
        return dateB.compareTo(dateA);
      });

      // (B) 정렬된 목록을 state에 반영
      state = rooms;
    } catch (e) {
      rethrow;
    }
  }

  /// (2) 채팅방 구독 해제
  Future<void> unsubscribe(int streamId) async {
    try {
      // Service에서 DELETE 요청
      await service.unsubscribeRoom(streamId);

      // 성공 후, state에서 해당 streamId 제거
      state = state.where((room) => room.streamId != streamId).toList();
    } catch (e) {
      rethrow;
    }
  }
}

/// 예: 문자열(ISO 8601 등)을 DateTime으로 파싱하는 함수
DateTime parseToDateTime(String timeString) {
  // 예: "2024-12-29T15:38:46.073812Z" → DateTime.parse(...)
  // 혹은 "오전 10:53" / "8월 1일" 형태라면, 형식에 맞게 재구성해야 함.
  // 여기서는 ISO 8601 가정.
  // 파싱 실패 시 1970-01-01 같은 기본값을 주거나, DateTime.now() 등 처리
  try {
    return DateTime.parse(timeString).toLocal();
  } catch (e) {
    // 파싱 실패 시, 매우 옛날 시간으로 처리해서 뒤로 가게 할 수도 있음
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
