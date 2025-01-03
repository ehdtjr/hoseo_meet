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
    final existingCircle = _circlesMap[userId];

    if (existingCircle != null) {
      // (1) 기존 circle가 있다면, 불변 객체 방식으로 "새 NCircleOverlay"를 생성
      final updatedCircle = NCircleOverlay(
        // "id: existingCircle.id," 부분은 제거 or 필요 없으면 생략
        // 지도가 식별자를 꼭 요구하지 않으면 이 라인 자체가 불필요합니다.
        center: NLatLng(lat, lng),
        radius: existingCircle.radius,
        color: existingCircle.color,
        outlineColor: existingCircle.outlineColor,
        outlineWidth: existingCircle.outlineWidth, id: '',
      );

      _circlesMap[userId] = updatedCircle;
    } else {
      // (2) 새로 추가되는 경우
      final newCircle = NCircleOverlay(
        // 새 오버레이에 'id'가 필요하다면, 여기서 userId 기반의 문자열을 지정
        // 만약 꼭 필요치 않다면 생략 가능 (id 필드가 optional이라면)
        id: 'circle_user_$userId',
        center: NLatLng(lat, lng),
        radius: 5,
        color: const Color.fromARGB(100, 255, 0, 0),
        outlineColor: Colors.red,
        outlineWidth: 2,
      );
      _circlesMap[userId] = newCircle;
    }

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
