import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoseomeet/features/home/data/models/room_review.dart';
import 'package:hoseomeet/features/home/presentation/widgets/room_page/review/review_button.dart';
import '../../../../../auth/presentation/pages/report_page.dart';
import '../../../../../auth/providers/user_profile_provider.dart';
import '../../../../providers/room/review/room_review_provider.dart';

class VisitorReviews extends ConsumerWidget {
  final int postId; // roomId 또는 postId로 사용

  const VisitorReviews({super.key, required this.postId});
  bool isValidUrl(String? url) {
    return url != null &&
        url.isNotEmpty &&
        Uri.tryParse(url)?.hasAbsolutePath == true;
  }


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Provider에서 해당 postId에 대한 리뷰 데이터를 가져옴
    final List<RoomReview> reviews = ref.watch(roomReviewProvider(postId));
    // Notifier를 통해 로딩 상태와 추가 데이터 로드 호출 가능
    final roomReviewNotifier = ref.watch(roomReviewProvider(postId).notifier);
    final isLoading = roomReviewNotifier.isLoading;
    final hasMore = roomReviewNotifier.hasMore;

    // 현재 로그인한 사용자 정보
    final userProfileState = ref.watch(userProfileNotifierProvider);
    final currentUserId = userProfileState.userProfile?.id;

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
                    // 리뷰 상단: 프로필, 작성자, 별점, 날짜, 신고하기/삭제 버튼
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 프로필 사진
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.grey.shade300,
                          backgroundImage: isValidUrl(review.author.profile)
                              ? NetworkImage(review.author.profile)
                              : null,
                          child: !isValidUrl(review.author.profile)
                              ? const Icon(Icons.person, color: Colors.white, size: 28)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 작성자 이름과 리뷰 수 (예시: 리뷰 수 53)
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
                                  const Text(
                                    "리뷰 53",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF8A8A8A),
                                    ),
                                  ),
                                ],
                              ),
                              // 별점, 날짜, 신고하기 또는 삭제 버튼
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // 별점 표시 (review.rating 기반)
                                  Row(
                                    children: List.generate(5, (index) {
                                      if (index < review.rating.floor()) {
                                        return const Icon(Icons.star, color: Color(0xFFE72410), size: 18);
                                      } else if (index == review.rating.floor() &&
                                          (review.rating - review.rating.floor()) >= 0.5) {
                                        return const Icon(Icons.star_half, color: Color(0xFFE72410), size: 18);
                                      } else {
                                        return const Icon(Icons.star_border, color: Color(0xFFD9D9D9), size: 18);
                                      }
                                    }),
                                  ),
                                  const SizedBox(width: 8),
                                  // 날짜
                                  Text(
                                    "${review.createdAt.year}.${review.createdAt.month.toString().padLeft(2, '0')}.${review.createdAt.day.toString().padLeft(2, '0')}",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF707070),
                                    ),
                                  ),
                                  const Spacer(),
                                  // 만약 작성자와 현재 사용자의 id가 같다면 삭제 버튼을, 아니라면 신고하기 버튼을 표시
                                  if (currentUserId != null && review.author.id == currentUserId)
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 16, color: Colors.grey),
                                      onPressed: () {
                                        ref
                                            .read(roomReviewProvider(postId).notifier)
                                            .deleteRoomReview(review.id);
                                      },
                                    )
                                  else
                                    TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ReportPage(
                                              reportedUserId: review.author.id,
                                              reportedUserName: review.author.name,
                                              reportedUserProfile: review.author.profile,
                                            ),
                                          ),
                                        );
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
