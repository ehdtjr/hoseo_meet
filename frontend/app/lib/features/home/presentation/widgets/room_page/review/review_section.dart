import 'package:flutter/material.dart';
import '../../../../data/models/room/room_post_detail.dart';
import 'rating_overview.dart';
import 'photo_reviews.dart';
import 'visitor_reviews.dart';

class ReviewSection extends StatelessWidget {
  final RoomDetail roomDetail;

  const ReviewSection({super.key, required this.roomDetail});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Row(
          children: [
            const Text(
              "리뷰 ",
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            Text(
              roomDetail.reviewsCount.toString(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5F5F5F),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        RatingOverview(
          avgRating: roomDetail.avgRating,
          reviewCount: roomDetail.reviewsCount,
          reviewRatingCounts: roomDetail.reviewRatingCounts,
        ),
        const SizedBox(height: 20),
        PhotoReviews(postId: roomDetail.id),
        const SizedBox(height: 20),
        VisitorReviews(postId: roomDetail.id),
        const SizedBox(height: 20), // 버튼 하단 간격
      ],
    );
  }
}
