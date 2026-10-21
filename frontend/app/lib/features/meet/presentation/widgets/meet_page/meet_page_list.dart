import 'package:flutter/material.dart';
import 'meet_page_item.dart';

class MeetPostList extends StatelessWidget {
  final List<dynamic> meetPosts;
  final bool isLoading;
  final bool hasMore;
  final Function loadMore;

  const MeetPostList({
    super.key,
    required this.meetPosts,
    required this.isLoading,
    required this.hasMore,
    required this.loadMore,
  });

  @override
  Widget build(BuildContext context) {
    return meetPosts.isEmpty && isLoading
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: meetPosts.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == meetPosts.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            loadMore();
          });
          return const Center(child: CircularProgressIndicator());
        }
        final post = meetPosts[index];
        return MeetPageItem(post: post);
      },
    );
  }
}
