import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'restaurant_menu_notifier.dart';
import '../../../../../commons/network/auth_http_client_provider.dart';
import '../../../data/models/restaurant/restaurant_menu.dart';
import '../../../data/services/restaurant/restaurant_menu_service.dart';

/// 메뉴 API 서비스 Provider
final restaurantMenuServiceProvider = Provider<RestaurantMenuService>((ref) {
  final client = ref.watch(authHttpClientProvider);
  return RestaurantMenuService(client);
});

/// 메뉴 상태 Provider (전체 상태 포함)
final restaurantMenuProvider =
StateNotifierProvider<RestaurantMenuNotifier, AsyncValue<RestaurantMenuState>>((ref) {
  final service = ref.watch(restaurantMenuServiceProvider);
  return RestaurantMenuNotifier(service);
});

/// 현재 편집 모드 여부 Provider
final restaurantMenuEditModeProvider = Provider<bool>((ref) {
  final state = ref.watch(restaurantMenuProvider);
  return state.maybeWhen(
    data: (data) => data.editMode,
    orElse: () => false,
  );
});

/// 현재 편집 중인 메뉴 Provider
final selectedMenuForEditProvider = Provider<RestaurantMenu?>((ref) {
  final state = ref.watch(restaurantMenuProvider);
  return state.maybeWhen(
    data: (data) => data.selectedMenuForEdit,
    orElse: () => null,
  );
});
