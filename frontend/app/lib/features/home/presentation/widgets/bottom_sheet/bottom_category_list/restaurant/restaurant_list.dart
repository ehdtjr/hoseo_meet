import 'package:campusmeet/features/home/presentation/widgets/bottom_sheet/bottom_category_list/restaurant/restaurant_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../providers/restaurant/restaurant_post_provider.dart';


class RestaurantList extends ConsumerWidget {
  const RestaurantList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurantPosts = ref.watch(restaurantPostProvider);
    final notifier = ref.read(restaurantPostProvider.notifier);
    final isLoading = notifier.isLoading;
    final hasMore = notifier.hasMore;

    if (restaurantPosts.isEmpty && isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: restaurantPosts.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == restaurantPosts.length) {
          // 마지막 아이템 - 로딩 중
          WidgetsBinding.instance.addPostFrameCallback((_) {
            notifier.loadRestaurants(loadMore: true);
          });
          return const Center(child: CircularProgressIndicator());
        }

        final restaurant = restaurantPosts[index];

        return RestaurantItem(
          imageUrl: restaurant.images.isNotEmpty ? restaurant.images.first : '',
          title: restaurant.name,
          rating: restaurant.avgRating,
          reviewCount: restaurant.reviewCount,
          distance: restaurant.distance,
          comment: restaurant.comment?? restaurant.name,
          isHeart: restaurant.isHearted,
          postId: restaurant.id.toString(),
          onFavoriteToggle: () {
            if (restaurant.isHearted) {
              // 즐겨찾기 해제 (원하는 로직 구현)
              // notifier.unheartRestaurant(restaurant.id); // 필요 시 구현
            } else {
              // 즐겨찾기 등록
              // notifier.heartRestaurant(restaurant.id); // 필요 시 구현
            }
          },
        );
      },
    );
  }
}
