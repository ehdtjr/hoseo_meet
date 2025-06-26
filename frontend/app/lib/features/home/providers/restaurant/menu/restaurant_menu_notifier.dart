import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer';

import '../../../data/models/restaurant/restaurant_menu.dart';
import '../../../data/services/restaurant/restaurant_menu_service.dart';

class RestaurantMenuNotifier extends StateNotifier<AsyncValue<List<RestaurantMenu>>> {
  final RestaurantMenuService _service;

  RestaurantMenuNotifier(this._service) : super(const AsyncValue.loading());

  Future<void> loadMenus(int postId) async {
    state = const AsyncValue.loading();
    try {
      final menus = await _service.loadMenus(postId);
      state = AsyncValue.data(menus);
      log('🍽️ 메뉴 불러오기 성공 (${menus.length}개)');
    } catch (e, st) {
      final err = e.toString();
      if (err.contains('404') || err.contains('Not Found')) {
        state = const AsyncValue.data([]);
        log('📭 메뉴 없음 처리됨 (404)');
      } else {
        state = AsyncValue.error(e, st);
        log('❌ 메뉴 불러오기 실패: $e');
      }
    }
  }
}
