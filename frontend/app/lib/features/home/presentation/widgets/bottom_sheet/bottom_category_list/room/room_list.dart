import 'package:campusmeet/features/home/presentation/widgets/bottom_sheet/bottom_category_list/room/room_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../providers/room/room_post_provider.dart'; // RoomPostNotifier 관련 Provider

class RoomPostList extends ConsumerWidget {
  const RoomPostList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // RoomPostNotifier를 통해 RoomPost 리스트를 구독합니다.
    final roomPosts = ref.watch(roomPostProvider);
    // Notifier에서 상태를 직접 가져올 수 있습니다.
    final notifier = ref.read(roomPostProvider.notifier);
    final isLoading = notifier.isLoading;
    final hasMore = notifier.hasMore;

    if (roomPosts.isEmpty && isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: roomPosts.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == roomPosts.length) {
          // 더 로드할 데이터가 있다면, 화면 표시 후 추가 로드를 요청합니다.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            notifier.loadRoomPosts(loadMore: true);
          });
          return const Center(child: CircularProgressIndicator());
        }
        final roomPost = roomPosts[index];
        return RoomItem(
          imageUrl: roomPost.images.isNotEmpty ? roomPost.images.first : '',
          title: roomPost.name,
          rating: roomPost.avgRating,
          reviewCount: roomPost.reviewsCount,
          distance: roomPost.distance,
          description: roomPost.name, // 실제 설명 필드가 있다면 해당 값을 사용
          isHeart: roomPost.isHeart, // RoomPost 모델에 즐겨찾기 필드가 없으므로, 필요시 추가 구현
          postId: roomPost.id.toString(),
          onFavoriteToggle: () {
            if (roomPost.isHeart) {
              notifier.unheartRoom(roomPost.id); // 하트 취소
            } else {
              notifier.heartRoom(roomPost.id);   // 하트 등록
            }
          },

        );
      },
    );
  }
}
