import 'package:flutter/material.dart';

class VisitorReviews extends StatelessWidget {
  const VisitorReviews({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 상단 제목과 정렬 버튼
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
        const SizedBox(height: 12), // 제목과 첫 리뷰 간격
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 프로필 사진
                const CircleAvatar(
                  radius: 26,
                  backgroundImage: NetworkImage("https://cdnweb01.wikitree.co.kr/webdata/editor/202205/27/img_20220527090507_8370af5a.webp"),
                ),
                const SizedBox(width: 10), // 프로필 사진과 닉네임 간격
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 작성자 이름과 리뷰 수
                      const Row(
                        children: [
                          Text(
                            "sooyz12",
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                              color: Color(0xFF5F5F5F),
                            ),
                          ),
                          SizedBox(width: 4),
                          Text(
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
                        crossAxisAlignment: CrossAxisAlignment.center, // 별점과 텍스트의 높이 정렬
                        children: [
                          Row(
                            children: List.generate(5, (starIndex) {
                              return Icon(
                                starIndex < 4
                                    ? Icons.star
                                    : Icons.star_border, // 4개의 채워진 별과 1개의 빈 별
                                color: starIndex < 4 ? const Color(0xFFE72410) : const Color(0xFFD9D9D9),
                                size: 18,
                              );
                            }),
                          ),
                          const SizedBox(width: 8), // 별점과 날짜 사이 간격
                          const Text(
                            "2024.04.15",
                            style: TextStyle(
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
            // 사진 갤러리 (가로 슬라이딩)
            const SizedBox(height: 12), // 간격 줄이기
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 5,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        image: const DecorationImage(
                          image: NetworkImage(
                              "https://www.chosun.com/resizer/v2/ZRL5XVHKZVQZAZMEYDEDWENZGY.jpg?auth=c2535f7e1aac3ec04531377802d30d4199bc4b948f31507e0ae04a02cba31025&width=530&height=675&smart=true"),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20), // 갤러리와 텍스트 간격 최소화
            // 리뷰 텍스트
            const Text(
              "우동을 좋아해서 여러 곳을 다녀봤지만, 이 집은 단연 최고입니다. 국물은 감칠맛이 살아있고, 면발은 적당히 쫄깃해서 씹는 맛이 정말 좋았어요. 특히 유부가 들어간 우동이 정말 맛있었고, 양도 넉넉해 만족스러웠습니다.",
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF5F5F5F),
                height: 1.4, // 줄 간격 조정
              ),
            ),
          ],
        ),
      ],
    );
  }
}
