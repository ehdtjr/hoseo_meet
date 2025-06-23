import 'package:flutter/material.dart';
import '../../../data/models/restaurant/restaurant_post_detail.dart';

class RestaurantSummarySection extends StatelessWidget {
  final RestaurantPostDetail restaurant;

  const RestaurantSummarySection({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    // 👉 임시 comment 삽입
    final fakeComment = restaurant.comment?.trim().isNotEmpty == true
        ? restaurant.comment!
        : '신선한 재료로 만든 건강한 맛, 최고의 맛집!';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 가게명
          Text(
            restaurant.name,
            style: const TextStyle(
              fontSize: 24, // 조금 키움
              fontWeight: FontWeight.w700,
              color: Colors.black,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 4),

          // 소분류 텍스트
          const Text(
            '음식점',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF888888),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),

          // 별점 및 리뷰 수
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...List.generate(5, (index) {
                final isFilled = index < restaurant.avgRating.floor();
                final isHalf = index < restaurant.avgRating &&
                    index >= restaurant.avgRating.floor();

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Icon(
                    isFilled
                        ? Icons.star
                        : isHalf
                        ? Icons.star_half
                        : Icons.star_border,
                    size: 24,
                    color: Colors.redAccent,
                  ),
                );
              }),
              const SizedBox(width: 4),
              Text(
                '(${restaurant.reviewCount})',
                style: const TextStyle(fontSize: 13, color: Color(0xFF555555)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 코멘트 (임시 포함)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '"$fakeComment"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF666666),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
