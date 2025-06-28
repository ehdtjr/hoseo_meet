import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../commons/file/image_utils.dart';
import '../../../data/models/restaurant/restaurant_menmu_version.dart';
import '../../../data/models/restaurant/restaurant_menu.dart';
import '../../../data/services/restaurant/restaurant_menu_service.dart';

class RestaurantMenuNotifier extends StateNotifier<AsyncValue<RestaurantMenuState>> {
  final RestaurantMenuService _service;

  RestaurantMenuNotifier(this._service) : super(const AsyncValue.loading());

  // ✅ 메뉴 목록 로딩
  Future<void> loadMenus(int postId) async {
    state = const AsyncValue.loading();
    try {
      final menus = await _service.loadMenus(postId);
      state = AsyncValue.data(RestaurantMenuState(menus: menus));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // ✅ 메뉴 생성 (ensureWebP 안전 처리)
  Future<void> createMenuInState({
    required String name,
    required int price,
    required int postId,
    File? imageFile,
  }) async {
    state = state.whenData((s) => s); // 상태 유지

    File? webpImage;
    if (imageFile != null && !isWebP(imageFile.path)) {
      try {
        webpImage = await ensureWebP(imageFile);
      } catch (e) {
        print('⚠️ WebP 변환 실패: $e');
        webpImage = null; // 실패 시 null 처리
      }
    }

    try {
      await _service.createMenu(
        name: name,
        price: price,
        postId: postId,
        imageFile: webpImage,
      );

      // 생성 후 목록 새로 불러오기
      await loadMenus(postId);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // ✅ 메뉴 수정 (ensureWebP 안전 처리 + 수정 후 목록 새로 로딩)
  Future<void> updateMenuInState(
      RestaurantMenu updatedMenu, {
        File? imageFile,
      }) async {
    File? webpImage;
    if (imageFile != null && !isWebP(imageFile.path)) {
      try {
        webpImage = await ensureWebP(imageFile);
      } catch (e) {
        print('⚠️ WebP 변환 실패: $e');
        webpImage = null; // 실패 시 null 처리
      }
    }

    // Optimistic UI
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
      await _service.updateMenu(
        menuId: updatedMenu.id,
        name: updatedMenu.name,
        price: updatedMenu.price,
        imageFile: webpImage,
      );

      // ✅ 수정 후 목록 새로 로딩
      await loadMenus(updatedMenu.postId); // ⚠️ updatedMenu에 postId가 있어야 함
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // ✅ 메뉴 버전 이력 조회 (추가!)
  Future<List<RestaurantMenuVersion>> loadMenuVersions(
      int postId, {
        required int skip,
        required int limit,
      }) async {
    return _service.getMenuVersions(postId: postId, skip: skip, limit: limit);
  }


  // ✅ 편집 모드 진입
  void enterEditMode(RestaurantMenu menu) {
    state = state.whenData(
          (s) => s.copyWith(
        editMode: true,
        selectedMenuForEdit: menu,
      ),
    );
  }

  // ✅ 편집 모드 종료
  void exitEditMode() {
    state = state.whenData(
          (s) => s.copyWith(
        editMode: false,
        selectedMenuForEdit: null,
      ),
    );
  }

  // ✅ 편집 모드 토글
  void toggleEditMode() {
    state = state.whenData((s) {
      final newMode = !s.editMode;
      return s.copyWith(
        editMode: newMode,
        selectedMenuForEdit: newMode ? s.selectedMenuForEdit : null,
      );
    });
  }

  Future<void> rollbackMenuInState({
    required int menuVersionId,
    required int postId,
  }) async {
    try {
      await _service.rollbackMenu(menuVersionId);
      await loadMenus(postId); // 롤백 후 최신 메뉴 목록 갱신
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }


  // ✅ 현재 편집 중인 메뉴 가져오기
  RestaurantMenu? get selectedMenuForEdit {
    return state.maybeWhen(
      data: (data) => data.selectedMenuForEdit,
      orElse: () => null,
    );
  }

  // ✅ 현재 편집 모드 여부 가져오기
  bool get isEditMode {
    return state.maybeWhen(
      data: (data) => data.editMode,
      orElse: () => false,
    );
  }
}
