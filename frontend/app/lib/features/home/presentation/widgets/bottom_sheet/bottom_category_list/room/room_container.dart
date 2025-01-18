import 'package:flutter/material.dart';
import 'package:hoseomeet/features/home/presentation/widgets/bottom_sheet/bottom_category_list/room/room_list.dart';

class RoomContainerWidget extends StatefulWidget {
  const RoomContainerWidget({super.key});

  @override
  _RoomContainerWidgetState createState() => _RoomContainerWidgetState();
}

class _RoomContainerWidgetState extends State<RoomContainerWidget> {
  List<Map<String, dynamic>> roomPosts = [];
  bool isLoading = false;
  bool hasMore = true;
  bool _isDisposed = false; // dispose 상태를 추적

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _isDisposed = true; // 상태가 dispose 되었음을 표시
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (_isDisposed) return; // dispose 상태에서는 동작하지 않도록 방지

    setState(() {
      isLoading = true;
    });

    // 초기 데이터 로드 (임시 데이터 사용)
    await Future.delayed(const Duration(seconds: 2));

    if (_isDisposed) return; // dispose 상태에서 setState 방지

    setState(() {
      roomPosts = List.generate(10, (index) {
        return {
          'imageUrl': 'https://cdn.living-sense.co.kr/news/photo/201606/20160614_2_bodyimg_30434.jpg',
          'title': '방 ${index + 1}',
          'rating': (3.0 + (index % 3)).toDouble(),
          'reviewCount': 20 + index,
          'distance': '${100 + index}m',
          'description': '신선한 재료로 만든 건강한 맛, 최고의 맛집!',
          'isFavorite': index % 2 == 0,
        };
      });
      isLoading = false;
    });
  }

  Future<void> _loadMoreData() async {
    if (isLoading || !hasMore || _isDisposed) return; // dispose 상태 확인

    setState(() {
      isLoading = true;
    });

    // 추가 데이터 로드 (임시 데이터 사용)
    await Future.delayed(const Duration(seconds: 2));

    if (_isDisposed) return; // dispose 상태에서 setState 방지

    setState(() {
      final newPosts = List.generate(5, (index) {
        return {
          'imageUrl': 'https://via.placeholder.com/100',
          'title': '추가 방 ${roomPosts.length + index + 1}',
          'rating': (3.0 + ((roomPosts.length + index) % 3)).toDouble(),
          'reviewCount': 20 + roomPosts.length + index,
          'distance': '${100 + roomPosts.length + index}m',
          'description': '신선한 재료로 만든 건강한 맛, 최고의 맛집!',
          'isFavorite': (roomPosts.length + index) % 2 == 0,
        };
      });

      roomPosts.addAll(newPosts);
      isLoading = false;

      // 예제: 데이터 20개 이상이면 더 로드하지 않음
      if (roomPosts.length >= 20) {
        hasMore = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadInitialData,
      child: RoomPostList(
        roomPosts: roomPosts,
        isLoading: isLoading,
        hasMore: hasMore,
        loadMore: _loadMoreData,
      ),
    );
  }
}
