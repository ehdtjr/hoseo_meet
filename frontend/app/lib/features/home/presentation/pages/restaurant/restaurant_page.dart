import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/restaurant/restaurant_post_detail.dart';
import '../../../providers/restaurant/restaurant_post_provider.dart';
import '../../widgets/restaurant/restaurant_custom_scroll_view.dart';
import '../../widgets/restaurant/restaurant_header_widget.dart';
import '../../widgets/restaurant/restaurant_summary.dart';

class RestaurantPage extends ConsumerStatefulWidget {
  final String postId;
  const RestaurantPage({Key? key, required this.postId}) : super(key: key);

  @override
  ConsumerState<RestaurantPage> createState() => _RestaurantPageState();
}

class _RestaurantPageState extends ConsumerState<RestaurantPage> {
  late Future<RestaurantPostDetail?> futureRestaurantDetail = Future.value(null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final restaurantNotifier = ref.read(restaurantPostProvider.notifier);
      restaurantNotifier.resetAndLoad();
      setState(() {
        futureRestaurantDetail = restaurantNotifier.loadRestaurantDetail(
          int.parse(widget.postId),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<RestaurantPostDetail?>(
        future: futureRestaurantDetail,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text("오류가 발생했습니다."));
          } else if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("상세 정보를 불러오지 못했습니다."));
          } else {
            final restaurant = snapshot.data!;
            return Column(
              children: [
                // 상단 이미지 및 제목 등
                RestaurantItemHeader(
                  expandedHeight: 300,
                  imageUrls: restaurant.images,
                ),
                RestaurantSummarySection(restaurant: restaurant),
                // 상세 본문 스크롤
                Expanded(
                   child: RestaurantCustomScrollView(restaurant: restaurant),
                ),
              ],
            );
          }
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
