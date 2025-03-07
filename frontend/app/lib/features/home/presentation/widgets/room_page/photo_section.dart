import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../providers/room/review/room_review_provider.dart';

class PhotoSection extends ConsumerWidget {
  final int postId;
  const PhotoSection({Key? key, required this.postId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Provider의 state를 구독하여 이미지 데이터가 변경되면 rebuild 되도록 함
    final roomReviewState = ref.watch(roomReviewProvider(postId));
    // notifier를 통해 images와 로딩 상태에 접근
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
      content = MasonryGridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverSimpleGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
        ),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        itemCount: images.length,
        itemBuilder: (context, index) {
          final image = images[index];
          return Container(
            // 이미지의 실제 비율이나 원하는 디자인에 따라 높이를 조절합니다.
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: NetworkImage(image.image),
                fit: BoxFit.cover,
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
          "사진",
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        content,
      ],
    );
  }
}
