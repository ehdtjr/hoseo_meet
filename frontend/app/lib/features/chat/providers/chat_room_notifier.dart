import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat_room.dart';
import '../data/services/chat_room_service.dart'; // ChatRoomService import

class ChatRoomNotifier extends StateNotifier<List<ChatRoom>> {
  final ChatRoomService service;

  ChatRoomNotifier(this.service) : super([]);

  /// (1) 채팅방 목록 불러오기
  Future<void> fetchRooms() async {
    try {
      final rooms = await service.loadRoomList(); // Service에서 목록 불러오기
      state = rooms;
    } catch (e) {
      // 에러 처리 로직
      rethrow;
    }
  }

  /// (2) 채팅방 구독 해제
  Future<void> unsubscribe(int streamId) async {
    try {
      // Service에서 DELETE 요청
      await service.unsubscribeRoom(streamId);

      // 성공 후, state에서 해당 streamId 제거 or 재조회
      state = state.where((room) => room.streamId != streamId).toList();
    } catch (e) {
      rethrow;
    }
  }
}
