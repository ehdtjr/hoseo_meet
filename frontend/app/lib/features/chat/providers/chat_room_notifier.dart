import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoseomeet/features/chat/data/models/chat_message.dart';
import '../data/models/chat_room.dart';
import '../data/services/chat_room_service.dart';

class ChatRoomNotifier extends StateNotifier<List<ChatRoom>> {
  final ChatRoomService service;
  bool _isExitMode = false;
  final Set<int> _roomsToRemove = {};

  ChatRoomNotifier(this.service) : super([]);

  bool get isExitMode => _isExitMode;

  /// 나가기 모드 토글
  void toggleExitMode() {
    if (_isExitMode) {
      // 나가기 모드가 true → false로 변경될 때 선택 상태 초기화
      clearRoomsToRemove();
    }

    _isExitMode = !_isExitMode;

    // 상태 변경 후 UI 갱신
    _updateState([...state]);
  }


  /// 방 선택/해제 토글
  void toggleRoomRemoval(int streamId) {
    if (_roomsToRemove.contains(streamId)) {
      _roomsToRemove.remove(streamId);
    } else {
      _roomsToRemove.add(streamId);
    }
    _updateState([...state]); // 상태 갱신
  }

  /// 선택된 방 리스트 반환
  List<ChatRoom> get roomsToRemove {
    return state.where((room) => _roomsToRemove.contains(room.streamId)).toList();
  }

  /// 선택 상태 초기화
  void clearRoomsToRemove() {
    _roomsToRemove.clear();
  }

  /// 선택된 방 구독 해제
  Future<void> removeSelectedRooms() async {
    try {
      for (final streamId in _roomsToRemove) {
        await service.unsubscribeRoom(streamId);
      }
      state = state.where((room) => !_roomsToRemove.contains(room.streamId)).toList();
      clearRoomsToRemove(); // 선택 상태 초기화
      _updateState([...state]); // 상태 갱신
    } catch (e) {
      rethrow;
    }
  }

  /// 채팅방 목록 불러오기
  Future<void> fetchRooms() async {
    try {
      final rooms = await service.loadRoomList();
      _updateState(rooms); // 상태 갱신
    } catch (e) {
      rethrow;
    }
  }

  /// 채팅방 구독 해제
  Future<void> unsubscribe(int streamId) async {
    try {
      await service.unsubscribeRoom(streamId);
      state = state.where((room) => room.streamId != streamId).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// 방을 읽은 상태로 표시 (unreadCount = 0)
  void markRoomAsRead(int streamId) {
    final updatedRooms = state.map((room) {
      if (room.streamId == streamId) {
        return room.copyWith(unreadCount: 0);
      }
      return room;
    }).toList();
    _updateState(updatedRooms); // 상태 갱신
  }

  /// 새로운 메시지 수신 시 처리
  void handleIncomingMessage({
    required ChatMessage newMessage,
    bool markAsRead = false,
  }) {
    final updatedRooms = state.map((room) {
      if (room.streamId == newMessage.streamId) {
        return room.copyWith(
          lastMessageContent: newMessage.content,
          time: newMessage.dateSent.toString(),
          unreadCount: markAsRead ? 0 : room.unreadCount + 1,
        );
      }
      return room;
    }).toList();

    _updateState(updatedRooms); // 상태 갱신
  }

  /// 상태 갱신 메서드
  void _updateState(List<ChatRoom> rooms) {
    _sortRoomsByConditions(rooms);
    state = rooms;
  }

  /// 방 목록 정렬 조건
  void _sortRoomsByConditions(List<ChatRoom> rooms) {
    rooms.sort((a, b) {
      final aUnread = a.unreadCount > 0;
      final bUnread = b.unreadCount > 0;

      if (aUnread && !bUnread) {
        return -1;
      } else if (!aUnread && bUnread) {
        return 1;
      }

      if (a.time.isEmpty && b.time.isNotEmpty) {
        return 1;
      } else if (b.time.isEmpty && a.time.isNotEmpty) {
        return -1;
      } else if (a.time.isEmpty && b.time.isEmpty) {
        return 0;
      }

      final dateA = parseToDateTime(a.time);
      final dateB = parseToDateTime(b.time);
      return dateB.compareTo(dateA); // 최신 메시지가 위로 오도록 내림차순 정렬
    });
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
