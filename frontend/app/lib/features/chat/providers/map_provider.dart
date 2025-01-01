import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:riverpod/riverpod.dart';
import 'map_notifier.dart';

/// NCircleOverlay를 관리하는 MapNotifier
final mapNotifierProvider =
StateNotifierProvider<MapNotifier, List<NCircleOverlay>>((ref) {
  return MapNotifier();
});
