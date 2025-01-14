import 'package:flutter/material.dart';
import '../../../data/models/meet_post_detail.dart';
import 'meet_author_section.dart'; // 새로 만든 파일 import
import 'meet_detail_footer.dart'; // MeetDetailFooter import

class MeetDetailModal extends StatelessWidget {
  final MeetDetail post;

  const MeetDetailModal({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 382,
      height: 250,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 작성자 섹션
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 25, 10),
            child: MeetAuthorSection(post: post),
          ),
          const Divider(
            color: Color(0xFFF0B4AD),
            thickness: 0.75,
          ),

          // 본문 내용 섹션
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 15, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 제목
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    post.title,
                    style: _TextStyles.title,
                  ),
                ),
                Container(
                  width: double.infinity,
                  height: 78, // 고정 높이 설정
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Text(
                    post.content,
                    style: _TextStyles.content,
                    maxLines: 3, // 최대 3줄까지 표시
                    overflow: TextOverflow.ellipsis, // 초과된 내용은 ...으로 표시
                  ),
                ),

              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: MeetDetailFooter(
              createdAt: post.createdAt,
              pageViews: post.pageViews,
              currentPeople: post.currentPeople,
              maxPeople: post.maxPeople,
              isSubscribed: post.isSubscribed,
            ),
          )

        ],
      ),
    );
  }

}

class _TextStyles {
  static const TextStyle title = TextStyle(
    color: Colors.black,
    fontSize: 15,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle content = TextStyle(
    color: Color(0xFF707070),
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

}
