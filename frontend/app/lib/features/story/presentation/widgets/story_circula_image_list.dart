import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/story_post.dart';
import '../pages/story_detail_page.dart';
import 'add_new_circular_image_widget.dart';
import '../../providers/story_post_provider.dart';

class StoryCircularImageList extends ConsumerWidget {
  const StoryCircularImageList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storyState = ref.watch(storyPostProvider);

    return SizedBox(
      height: 80,
      child: storyState.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: storyState.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return const Padding(
              padding: EdgeInsets.only(right: 15.0),
              child: AddNewCircularImageWidget(),
            );
          }
          final story = storyState[index - 1];
          return Padding(
            padding: const EdgeInsets.only(right: 15.0),
            child: _ImageItemWidget(
              story: story,
              stories: storyState,
              index: index - 1,
            ),
          );
        },
      ),
    );
  }
}

class _ImageItemWidget extends StatelessWidget {
  final StoryPost story;
  final List<StoryPost> stories;
  final int index;

  const _ImageItemWidget({
    required this.story,
    required this.stories,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StoryDetailPage(
              stories: stories,
              initialIndex: index,
            ),
          ),
        );
      },
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.red, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(1),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: NetworkImage(story.imageUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
