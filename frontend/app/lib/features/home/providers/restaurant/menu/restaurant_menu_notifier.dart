import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/restaurant/restaurant_menu.dart';
import '../../../data/services/restaurant/restaurant_menu_service.dart';

class RestaurantMenuNotifier extends StateNotifier<AsyncValue<RestaurantMenuState>> {
  final RestaurantMenuService _service;

  RestaurantMenuNotifier(this._service) : super(const AsyncValue.loading());

  // 메뉴 목록 로딩
  Future<void> loadMenus(int postId) async {
    state = const AsyncValue.loading();
    try {
      final menus = await _service.loadMenus(postId);
      state = AsyncValue.data(RestaurantMenuState(menus: menus));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // 편집 모드 진입 (특정 메뉴 대상으로)
  void enterEditMode(RestaurantMenu menu) {
    state = state.whenData((s) => s.copyWith(
      editMode: true,
      selectedMenuForEdit: menu,
    ));
  }

  // 편집 모드 종료
  void exitEditMode() {
    state = state.whenData((s) => s.copyWith(
      editMode: false,
      selectedMenuForEdit: null,
    ));
  }

  // 편집 모드 토글 (단일 버튼 처리용)
  void toggleEditMode() {
    state = state.whenData((s) {
      final newMode = !s.editMode;
      return s.copyWith(
        editMode: newMode,
        selectedMenuForEdit: newMode ? s.selectedMenuForEdit : null,
      );
    });
  }

  // 메뉴 정보를 수정하고 상태에 반영
  Future<void> updateMenuInState(RestaurantMenu updatedMenu, {File? imageFile}) async {
    // optimistic UI 적용 (선반영)
    state = state.whenData((s) {
      final updatedMenus = s.menus.map((m) {
        return m.id == updatedMenu.id ? updatedMenu : m;
      }).toList();
      return s.copyWith(
        menus: updatedMenus,
        selectedMenuForEdit: null,
        editMode: false,
      );
    });

    try {
      // 서버에 반영
      await _service.updateMenu(
        menuId: updatedMenu.id,
        name: updatedMenu.name,
        price: updatedMenu.price,
        imageFile: imageFile,
      );
    } catch (e, st) {
      // 실패 시 다시 로딩 (또는 에러 처리 방식 추가)
      state = AsyncValue.error(e, st);
    }
  }


  // 현재 편집 중인 메뉴 가져오기
  RestaurantMenu? get selectedMenuForEdit {
    return state.maybeWhen(
      data: (data) => data.selectedMenuForEdit,
      orElse: () => null,
    );
  }

  // 현재 편집 모드 여부 가져오기
  bool get isEditMode {
    return state.maybeWhen(
      data: (data) => data.editMode,
      orElse: () => false,
    );
  }
}
