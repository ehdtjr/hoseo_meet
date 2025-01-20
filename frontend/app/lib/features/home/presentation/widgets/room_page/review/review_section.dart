import 'package:flutter/material.dart';
import 'rating_overview.dart';
import 'photo_reviews.dart';
import 'visitor_reviews.dart';
import 'review_button.dart';

class ReviewSection extends StatelessWidget {
  final String postId;

  const ReviewSection({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              "리뷰 ",
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            Text(
              "31",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5F5F5F),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const RatingOverview(),
        const SizedBox(height: 20),
        const PhotoReviews(),
        const SizedBox(height: 20),
        const VisitorReviews(),
        const SizedBox(height: 20),
        // 분리된 버튼 추가
        ReviewButton(
          onPressed: () {
            print("더보기 버튼 클릭됨");
          },
        ),
        const SizedBox(height: 20), // 버튼 하단 간격
      ],
    );
  }
}
