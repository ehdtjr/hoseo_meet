import 'package:flutter/material.dart';

class RatingOverview extends StatelessWidget {
  final double avgRating;
  final int reviewCount;
  final Map<int, int> reviewRatingCounts;

  const RatingOverview({
    super.key,
    required this.avgRating,
    required this.reviewCount,
    required this.reviewRatingCounts,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.center, // 가운데 정렬
          children: [
            Text(
              avgRating.toStringAsFixed(1), // ✅ 평균 평점을 적용
              style: const TextStyle(
                fontSize: 21,
                color: Color(0xFF2F2F2F),
              ),
            ),
            const SizedBox(height: 4), // 텍스트와 별 간의 간격
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                if (index < avgRating.floor()) {
                  // 정수 부분: 꽉 찬 별
                  return Icon(Icons.star, color: Colors.red, size: 24);
                } else if (index == avgRating.floor() && (avgRating - avgRating.floor()) >= 0.5) {
                  // 소수 부분이 0.5 이상이면: 반 별
                  return Icon(Icons.star_half, color: Colors.red, size: 24);
                } else {
                  // 나머지는 빈 별
                  return Icon(Icons.star_border, color: Colors.red, size: 24);
                }
              }),
            ),
            const SizedBox(height: 10), // 별과 "별점" 텍스트 간의 간격
            Text(
              "(${reviewCount.toString()})",
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        )
        ,
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: List.generate(5, (index) {
              int rating = 5 - index; // 5점부터 1점까지 순서대로 표시
              int count = reviewRatingCounts[rating] ?? 0; // 해당 점수의 리뷰 개수
              int maxReviewCount = reviewRatingCounts.values.isNotEmpty
                  ? reviewRatingCounts.values.reduce((a, b) => a > b ? a : b)
                  : 1; // 가장 많이 받은 리뷰 개수 (정규화 기준)

              double ratio = maxReviewCount > 0 ? count / maxReviewCount : 0.0; // 비율 계산

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Row(
                  children: [
                    Text(
                      "$rating점",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(width: 8),

                    // 빨간색 바 (리뷰 개수 반영)
                    Expanded(
                      flex: (ratio * 100).toInt(), // 비율을 기반으로 크기 조정
                      child: Container(
                        height: 8,
                        color: Colors.red,
                      ),
                    ),

                    // 회색 바 (남은 공간)
                    Expanded(
                      flex: ((1 - ratio) * 100).toInt(),
                      child: Container(
                        height: 8,
                        color: Colors.grey[300],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "$count",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
