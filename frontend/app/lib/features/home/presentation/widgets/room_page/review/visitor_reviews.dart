import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoseomeet/features/home/data/models/room_review.dart';
import 'package:hoseomeet/features/home/presentation/widgets/room_page/review/review_button.dart';
import '../../../../providers/room/review/room_review_provider.dart';

class VisitorReviews extends ConsumerWidget {
  final int postId; // roomId 또는 postId로 사용

  const VisitorReviews({Key? key, required this.postId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Provider에서 해당 postId에 대한 리뷰 데이터를 가져옴
    final List<RoomReview> reviews = ref.watch(roomReviewProvider(postId));
    // Notifier를 통해 로딩 상태와 추가 데이터 로드 호출 가능
    final roomReviewNotifier = ref.watch(roomReviewProvider(postId).notifier);
    final isLoading = roomReviewNotifier.isLoading;
    final hasMore = roomReviewNotifier.hasMore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 상단 제목과 정렬 버튼 (고정 UI)
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "방문자 리뷰",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Text(
                  "최신순",
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF5F5F5F),
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down,
                  color: Color(0xFF5F5F5F),
                  size: 16,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 리뷰 데이터가 로딩 중이면 인디케이터, 데이터가 없으면 "리뷰없음" 텍스트 표시
        if (reviews.isEmpty)
          Center(
            child: isLoading
                ? const CircularProgressIndicator()
                : const Text(
              "리뷰없음",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          )
        else
        // 리뷰 데이터를 리스트로 보여줌
          ListView.builder(
            shrinkWrap: true, // Column 내부에 ListView 사용 시 반드시 shrinkWrap 사용
            physics: const NeverScrollableScrollPhysics(), // 내부 스크롤 방지
            itemCount: reviews.length,
            itemBuilder: (context, index) {
              final review = reviews[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 리뷰 상단: 프로필, 작성자, 별점, 날짜, 신고하기 버튼
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 프로필 사진
                        CircleAvatar(
                          radius: 26,
                          backgroundImage: NetworkImage(review.author.profile),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 작성자 이름과 리뷰 수 (리뷰 수는 예시로 고정)
                              Row(
                                children: [
                                  Text(
                                    review.author.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 16,
                                      color: Color(0xFF5F5F5F),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  // 예시: "리뷰 53" 대신 review 데이터에 리뷰 개수가 있다면 표시
                                  const Text(
                                    "리뷰 53",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF8A8A8A),
                                    ),
                                  ),
                                ],
                              ),
                              // 별점, 날짜, 신고하기 버튼
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // 별점 표시 (review.rating를 기반으로 별 그리기)
                                  Row(
                                    children: List.generate(5, (index) {
                                      // full star: 인덱스가 rating의 정수 부분보다 작으면
                                      if (index < review.rating.floor()) {
                                        return const Icon(Icons.star, color: Color(0xFFE72410), size: 18);
                                      }
                                      // half star: 인덱스가 정수 부분과 같고, 소수 부분이 0.5 이상이면
                                      else if (index == review.rating.floor() && (review.rating - review.rating.floor()) >= 0.5) {
                                        return const Icon(Icons.star_half, color: Color(0xFFE72410), size: 18);
                                      }
                                      // empty star
                                      else {
                                        return const Icon(Icons.star_border, color: Color(0xFFD9D9D9), size: 18);
                                      }
                                    }),
                                  ),
                                  const SizedBox(width: 8),
                                  // 날짜 (예시 포맷)
                                  Text(
                                    "${review.createdAt.year}.${review.createdAt.month.toString().padLeft(2, '0')}.${review.createdAt.day.toString().padLeft(2, '0')}",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF707070),
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () {
                                      // 신고하기 동작 추가
                                    },
                                    child: const Text(
                                      "신고하기",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF8A8A8A),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 이미지가 있을 때만 사진 갤러리 표시
                    if (review.images.isNotEmpty)
                      SizedBox(
                        height: 140,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: review.images.length,
                          itemBuilder: (context, imageIndex) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  image: DecorationImage(
                                    image: NetworkImage(review.images[imageIndex]),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 20),
                    // 리뷰 텍스트
                    Text(
                      review.content,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF5F5F5F),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 20),
        if (hasMore)
          ReviewButton(
            onPressed: () {
              ref
                  .read(roomReviewProvider(postId).notifier)
                  .loadRoomReviews(loadMore: true);
            },
          ),
      ],
    );
  }
}
