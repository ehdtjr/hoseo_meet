import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/meet_post_detail.dart';
import '../../../providers/meet_post_provider.dart';
import 'meet_author_section.dart';
import 'meet_detail_footer.dart';

class MeetDetailModal extends ConsumerWidget {
  final MeetDetail post;

  const MeetDetailModal({super.key, required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: 382,
      height: 250,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 작성자 섹션
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 25, 10),
            child: MeetAuthorSection(
              post: post,
              onDelete: () async {
                final notifier = ref.read(meetPostProvider.notifier);
                try {
                  await notifier.deleteMeetPost(post.id);
                  Navigator.of(context).pop(); // 삭제 후 모달 닫기
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('삭제되었습니다')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('삭제 중 오류가 발생했습니다')),
                  );
                }
              },
            ),
          ),

          const Divider(
            color: Color(0xFFF0B4AD),
            thickness: 0.75,
          ),

          // 제목 & 내용
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 15, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post.title, style: _TextStyles.title),
                Container(
                  width: double.infinity,
                  height: 78,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Text(
                    post.content,
                    style: _TextStyles.content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // 참여/정보 푸터
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: MeetDetailFooter(postId: post.id),
          ),
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
