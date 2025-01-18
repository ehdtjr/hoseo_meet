import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../meet/presentation/widgets/meet_page/meet_page_list.dart';
import '../../../../../../meet/providers/meet_post_provider.dart';

class MeetContainerWidget extends ConsumerWidget {
  const MeetContainerWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetPosts = ref.watch(meetPostProvider);
    final notifier = ref.read(meetPostProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              notifier.resetAndLoad(); // 새 데이터 로드
            },
            child: MeetPostList(
              meetPosts: meetPosts,
              isLoading: notifier.isLoading,
              hasMore: notifier.hasMore,
              loadMore: () => notifier.loadMeetPosts(loadMore: true),
            ),
          ),
        ),
      ],
    );
  }
}
