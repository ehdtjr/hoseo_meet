import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../providers/restaurant/restaurant_post_category_provider.dart';

class RestaurantHeaderWidget extends ConsumerWidget {
  final String userName;

  const RestaurantHeaderWidget({
    super.key,
    required this.userName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayUserName = userName.length > 4
        ? '${userName.substring(0, 4)}...'
        : userName;

    final selectedCategory = ref.watch(restaurantCategoryProvider);
    const Color highlightColor = Color(0xFFE72410); // 강조 색상

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: '지금 ',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text: displayUserName,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w600,
                          color: highlightColor,
                        ),
                      ),
                      const TextSpan(
                        text: '님 주위에 있는 ',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const TextSpan(
                        text: '맛집',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w600,
                          color: highlightColor,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<RestaurantCategory>(
                  dropdownColor: Colors.white,
                  value: selectedCategory,
                  isDense: true,
                  menuMaxHeight: 200,
                  items: RestaurantCategory.values.map((category) {
                    return DropdownMenuItem<RestaurantCategory>(
                      value: category,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          _categoryToString(category),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF9F9F9F),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (RestaurantCategory? value) {
                    if (value != null) {
                      ref.read(restaurantCategoryProvider.notifier).state = value;
                    }
                  },
                  style: const TextStyle(color: Color(0xFF5F5F5F), fontSize: 14),
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    size: 18,
                    color: Color(0xFF5F5F5F),
                  ),
                  selectedItemBuilder: (BuildContext context) {
                    return RestaurantCategory.values.map((category) {
                      return Text(
                        _categoryToString(category),
                        style: const TextStyle(
                          color: Color(0xFF5F5F5F),
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// RestaurantCategory를 한글 문자열로 변환
  String _categoryToString(RestaurantCategory category) {
    switch (category) {
      case RestaurantCategory.distance:
        return '거리순';
      case RestaurantCategory.rating:
        return '별점순';
      case RestaurantCategory.reviews:
        return '리뷰순';
      case RestaurantCategory.heart:
        return '찜목록';
    }
  }
}
