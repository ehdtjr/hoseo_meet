import 'package:flutter/material.dart';
import 'room_item.dart'; // RoomItem 위젯의 경로를 설정하세요.

class RoomPostList extends StatelessWidget {
  final List<dynamic> roomPosts; // 방 데이터 리스트
  final bool isLoading; // 로딩 상태
  final bool hasMore; // 추가 데이터 여부
  final Function loadMore; // 추가 데이터 로드 함수

  const RoomPostList({
    super.key,
    required this.roomPosts,
    required this.isLoading,
    required this.hasMore,
    required this.loadMore,
  });

  @override
  Widget build(BuildContext context) {
    return roomPosts.isEmpty && isLoading
        ? const Center(child: CircularProgressIndicator()) // 로딩 상태 표시
        : ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: roomPosts.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == roomPosts.length) {
          // 더 로드할 데이터가 있는 경우 로딩 표시
          WidgetsBinding.instance.addPostFrameCallback((_) {
            loadMore();
          });
          return const Center(child: CircularProgressIndicator());
        }
        final roomPost = roomPosts[index];
        return RoomItem(
          imageUrl: roomPost['imageUrl'], // 이미지 URL
          title: roomPost['title'], // 제목
          rating: roomPost['rating'], // 별점
          reviewCount: roomPost['reviewCount'], // 리뷰 수
          distance: roomPost['distance'], // 거리
          description: roomPost['description'], // 설명
          isFavorite: roomPost['isFavorite'], // 즐겨찾기 여부
          onFavoriteToggle: () {
            // 즐겨찾기 토글 처리 (사용자 정의 로직 추가)
            print('${roomPost['title']} 즐겨찾기 토글');
          },
        );
      },
    );
  }
}
