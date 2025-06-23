import 'package:flutter/material.dart';

import '../../../../pages/restaurant/restaurant_page.dart';


class RestaurantItem extends StatelessWidget {
  final String imageUrl;
  final String title;
  final double rating;
  final int reviewCount;
  final int distance;
  final String comment;
  final bool isHeart;
  final VoidCallback onFavoriteToggle;
  final String postId;

  const RestaurantItem({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.rating,
    required this.reviewCount,
    required this.distance,
    required this.comment,
    required this.isHeart,
    required this.onFavoriteToggle,
    required this.postId,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RestaurantPage(postId: postId),
          ),
        );
      },
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 100,
                          height: 100,
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 28),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: List.generate(5, (index) {
                            return Icon(
                              index < rating
                                  ? Icons.star
                                  : Icons.star_border,
                              color: const Color(0xFFE72410),
                              size: 24,
                            );
                          }),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              '$distance m',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF000000),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10.0),
                              child: SizedBox(
                                height: 15.0,
                                child: VerticalDivider(
                                  color: Color(0xFFD9D9D9),
                                  thickness: 1.0,
                                  width: 1.0,
                                ),
                              ),
                            ),
                            Text(
                              '리뷰 $reviewCount',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF000000),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onFavoriteToggle,
                    icon: Icon(
                      isHeart ? Icons.favorite : Icons.favorite_border,
                      color: isHeart ? const Color(0xFFE72410) : const Color(0xFF9F9F9F),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFCF5F4),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              comment,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF9F9F9F),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
