import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/room/review/room_review_provider.dart';

class PhotoReviews extends ConsumerWidget {
  final int postId;
  const PhotoReviews({Key? key, required this.postId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // state를 구독하여 notifier의 변경 사항(예: images 업데이트)이 rebuild에 반영되도록 함
    ref.watch(roomReviewProvider(postId));
    // notifier에 접근하여 images 및 로딩 상태를 읽음
    final roomReviewNotifier = ref.watch(roomReviewProvider(postId).notifier);
    final images = roomReviewNotifier.images;
    final isLoading = roomReviewNotifier.isImageLoading;

    Widget content;
    if (isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (images.isEmpty) {
      content = const Center(
        child: Text(
          "사진 리뷰가 없습니다.",
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
      );
    } else {
      content = ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        itemBuilder: (context, index) {
          final image = images[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Container(
              width: 90,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: NetworkImage(image.image),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "사진 리뷰",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 90,
          child: content,
        ),
      ],
    );
  }
}
