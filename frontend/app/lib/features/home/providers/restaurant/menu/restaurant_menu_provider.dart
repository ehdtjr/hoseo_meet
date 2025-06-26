import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'restaurant_menu_notifier.dart';
import '../../../../../commons/network/auth_http_client_provider.dart';
import '../../../data/models/restaurant/restaurant_menu.dart';
import '../../../data/services/restaurant/restaurant_menu_service.dart';

final restaurantMenuServiceProvider = Provider<RestaurantMenuService>((ref) {
  final client = ref.watch(authHttpClientProvider);
  return RestaurantMenuService(client);
});

final restaurantMenuProvider =
StateNotifierProvider<RestaurantMenuNotifier, AsyncValue<List<RestaurantMenu>>>(
      (ref) {
    final service = ref.watch(restaurantMenuServiceProvider);
    return RestaurantMenuNotifier(service);
  },
);

final restaurantMenuEditModeProvider = StateProvider<bool>((ref) => false);
