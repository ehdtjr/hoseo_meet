import 'package:flutter_riverpod/flutter_riverpod.dart';

enum RoomPostCategory {distance, rating, reviews }

final roomPostCategoryProvider = StateProvider<RoomPostCategory>((ref) {
  return RoomPostCategory.distance;
});