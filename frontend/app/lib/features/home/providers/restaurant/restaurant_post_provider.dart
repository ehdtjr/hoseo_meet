import 'package:campusmeet/features/home/providers/restaurant/restaurant_post_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../commons/network/auth_http_client_provider.dart';
import '../../data/models/restaurant/restaurant_post.dart';
import '../../data/services/restaurant/restaurant_post_service.dart';


final restaurantServiceProvider = Provider<RestaurantService>((ref) {
  final client = ref.watch(authHttpClientProvider);
  return RestaurantService(client);
});

final restaurantPostProvider =
StateNotifierProvider<RestaurantNotifier, List<Restaurant>>((ref) {
  final service = ref.watch(restaurantServiceProvider);
  return RestaurantNotifier(service, ref);
});

final restaurantSearchKeywordProvider = StateProvider<String>((ref) => '');
