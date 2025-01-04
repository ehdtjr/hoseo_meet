import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:riverpod/riverpod.dart';

/// userId -> NCircleOverlay 매핑
class MapNotifier extends StateNotifier<List<NCircleOverlay>> {
  MapNotifier() : super([]);

  // 내부 Map: userId -> NCircleOverlay
  final Map<int, NCircleOverlay> _circlesMap = {};

  /// userId별 원(circle) 업데이트
  void updateUserCircle(int userId, double lat, double lng) {
      final newCircle = NCircleOverlay(
        id: 'circle_user_$userId',
        center: NLatLng(lat, lng),
        radius: 5,
        color: const Color.fromARGB(100, 255, 0, 0),
        outlineColor: Colors.red,
        outlineWidth: 2,
      );
      _circlesMap[userId] = newCircle;
    // (3) state를 새 리스트로 교체 → Riverpod가 "값 변경" 인식
    state = _circlesMap.values.toList();
  }

  /// userId 원 제거
  void removeUserCircle(int userId) {
    if (_circlesMap.containsKey(userId)) {
      _circlesMap.remove(userId);
      state = _circlesMap.values.toList();
    }
  }

  /// 현재 등록된 userId 목록
  List<int> get userIds => _circlesMap.keys.toList();

  /// userId의 위치(NLatLng) 반환 (없으면 null)
  NLatLng? getUserLatLng(int userId) => _circlesMap[userId]?.center;
}
