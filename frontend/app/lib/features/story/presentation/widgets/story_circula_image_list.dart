import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'add_new_circular_image_widget.dart';
import '../../providers/story_post_provider.dart';

class StoryCircularImageList extends ConsumerWidget {
  const StoryCircularImageList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storyState = ref.watch(storyPostProvider);

    return SizedBox(
      height: 80, // ✅ 크기 조정 (흰색 공간 포함)
      child: storyState.isEmpty
          ? const Center(child: CircularProgressIndicator()) // ✅ 로딩 표시
          : ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: storyState.length + 1, // 첫 번째 아이템 추가 버튼 포함
        itemBuilder: (context, index) {
          if (index == 0) {
            return const Padding(
              padding: EdgeInsets.only(right: 15.0),
              child: AddNewCircularImageWidget(),
            );
          }
          final story = storyState[index - 1]; // 데이터 매핑
          return Padding(
            padding: const EdgeInsets.only(right: 15.0),
            child: _ImageItemWidget(imageUrl: story.imageUrl),
          );
        },
      ),
    );
  }
}

class _ImageItemWidget extends StatelessWidget {
  final String imageUrl;

  const _ImageItemWidget({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80, // ✅ 전체 크기 (흰색 공간 포함)
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.red, width: 2), // 🔴 외곽 빨간 테두리
      ),
      child: Padding(
        padding: const EdgeInsets.all(1), // ⚪ 흰색 공간 (테두리 내부)
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white, // ⚪ 내부 흰색 공간
          ),
          child: Padding(
            padding: const EdgeInsets.all(2), // ✅ 이미지와 흰색 공간 사이의 여백
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
