import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../data/models/room_post_detail.dart';
import '../../../providers/room/room_post_provider.dart';
import '../../widgets/room_page/room_custom_scroll_view.dart';
import '../../widgets/room_page/room_header_widget.dart';

import 'create_room_review_page.dart';

class RoomPage extends ConsumerStatefulWidget {
  final String postId;
  const RoomPage({Key? key, required this.postId}) : super(key: key);

  @override
  ConsumerState<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends ConsumerState<RoomPage> {
  // 초기 future 값을 임시로 null 처리
  late Future<RoomDetail?> futureRoomDetail = Future.value(null);

  @override
  void initState() {
    super.initState();
    // 위젯 트리 빌드가 완료된 후에 provider 상태 변경 수행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final roomNotifier = ref.read(roomPostProvider.notifier);
      roomNotifier.resetAndLoad();
      setState(() {
        futureRoomDetail = roomNotifier.loadRoomDetail(int.parse(widget.postId));
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<RoomDetail?>(
        future: futureRoomDetail,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text("오류가 발생했습니다."));
          } else if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("상세 정보를 불러오지 못했습니다."));
          } else {
            final roomDetail = snapshot.data!;
            return Column(
              children: [
                // 헤더 (상단 이미지, 제목 등)
                RoomHeaderWidget(
                  expandedHeight: 300,
                  imageUrls: roomDetail.images,
                ),
                // 본문 스크롤
                Expanded(
                  child: RoomCustomScrollView(roomDetail: roomDetail),
                ),
              ],
            );
          }
        },
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 50), // 하단에서 원하는 만큼 위로 이동
        child: RawMaterialButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => CreateRoomReviewPage(roomId: widget.postId)),
            );
          },
          shape: const CircleBorder(),
          child: SvgPicture.asset(
            'assets/icons/review.svg',
            fit: BoxFit.fill,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
