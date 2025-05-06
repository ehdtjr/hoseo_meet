import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:riverpod/riverpod.dart';
import 'map_notifier.dart';

/// 사용자 ID별 위치(Map<int, NLatLng>)를 관리하는 MapNotifier
final mapNotifierProvider =
StateNotifierProvider<MapNotifier, Map<int, NLatLng>>((ref) {
  return MapNotifier();
});
