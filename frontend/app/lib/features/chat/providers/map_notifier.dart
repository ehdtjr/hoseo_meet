import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MapNotifier extends StateNotifier<Map<int, NLatLng>> {
  MapNotifier() : super({});

  /// 위치 업데이트 (값이 바뀔 때만 상태 변경)
  void updateUserPosition(int userId, double lat, double lng) {
    final current = state[userId];
    final newPosition = NLatLng(lat, lng);

    if (current == null ||
        current.latitude != newPosition.latitude ||
        current.longitude != newPosition.longitude) {
      state = {
        ...state,
        userId: newPosition,
      };
    }
  }

  /// 위치 제거
  void removeUser(int userId) {
    if (state.containsKey(userId)) {
      final newState = {...state}..remove(userId);
      state = newState;
    }
  }

  /// 현재 등록된 userId 목록
  List<int> get userIds => state.keys.toList();

  /// 특정 유저 위치
  NLatLng? getUserLatLng(int userId) => state[userId];
}
