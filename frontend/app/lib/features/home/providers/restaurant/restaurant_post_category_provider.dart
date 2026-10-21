import 'package:flutter_riverpod/flutter_riverpod.dart';

enum RestaurantCategory { distance, rating, reviews, heart }

final restaurantCategoryProvider = StateProvider<RestaurantCategory>((ref) {
  return RestaurantCategory.distance;
});
