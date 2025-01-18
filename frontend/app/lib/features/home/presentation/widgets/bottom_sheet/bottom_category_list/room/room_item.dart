import 'package:flutter/material.dart';

class RoomItem extends StatelessWidget {
  final String imageUrl;
  final String title;
  final double rating; // 별점 (0~5)
  final int reviewCount; // 리뷰 수
  final String distance; // 거리
  final String description; // 설명
  final bool isFavorite; // 즐겨찾기 여부
  final VoidCallback onFavoriteToggle; // 즐겨찾기 버튼 클릭 시 호출

  const RoomItem({
    Key? key,
    required this.imageUrl,
    required this.title,
    required this.rating,
    required this.reviewCount,
    required this.distance,
    required this.description,
    required this.isFavorite,
    required this.onFavoriteToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
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
                // 이미지
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 28),
                // 텍스트와 별점
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 제목 (여백 추가)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 4, // 위아래 여백
                        ),
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
                      // 별점과 리뷰, 거리
                      Row(
                        children: [
                          // 별점
                          Row(
                            children: List.generate(5, (index) {
                              return Icon(
                                index < rating
                                    ? Icons.star
                                    : Icons.star_border, // 별 채우기 or 빈 별
                                color: const Color(0xFFE72410), // 별 색상
                                size: 24,
                              );
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 거리와 리뷰
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          // 거리 텍스트
                          Text(
                            distance,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF000000),
                            ),
                          ),
                          // 세로 구분선
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
                          // 리뷰 텍스트
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

                // 즐겨찾기 버튼
                IconButton(
                  onPressed: onFavoriteToggle,
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? const Color(0xFFE72410) : const Color(0xFF9F9F9F),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Description 추가 (높이 고정)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          height: 40, // 높이 고정
          decoration: BoxDecoration(
            color: const Color(0xFFFCF5F4), // 배경색
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center, // 텍스트를 중앙 정렬
          child: Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF9F9F9F),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
