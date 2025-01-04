import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat_room.dart';
import '../data/services/chat_room_service.dart';

class ChatRoomNotifier extends StateNotifier<List<ChatRoom>> {
  final ChatRoomService service;

  ChatRoomNotifier(this.service) : super([]);

  // (1) 채팅방 목록 불러오기
  Future<void> fetchRooms() async {
    try {
      final rooms = await service.loadRoomList();

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

      state = rooms;
    } catch (e) {
      rethrow;
    }
  }

  // (2) 채팅방 구독 해제 (예시)
  Future<void> unsubscribe(int streamId) async {
    try {
      await service.unsubscribeRoom(streamId);
      state = state.where((room) => room.streamId != streamId).toList();
    } catch (e) {
      rethrow;
    }
  }

  // (3) "읽은 처리" 메서드 (unreadCount = 0)
  void markRoomAsRead(int streamId) {
    // state는 불변 리스트이므로, map을 돌면서 해당 room만 업데이트
    final updatedRooms = state.map((room) {
      if (room.streamId == streamId) {
        // ChatRoom 모델에 copyWith가 있다면 copyWith로 쉽게 처리 가능
        return room.copyWith(unreadCount: 0);
      } else {
        return room;
      }
    }).toList();

    // 변경된 목록을 state에 반영 → UI 자동 리빌드
    state = updatedRooms;
  }
}

// 날짜 파싱 예시
DateTime parseToDateTime(String timeString) {
  try {
    return DateTime.parse(timeString).toLocal();
  } catch (e) {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
