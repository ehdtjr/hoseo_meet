import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hoseomeet/features/home/presentation/widgets/room_page/room_custom_scroll_view.dart';
import '../../../providers/room/room_post_provider.dart';
import '../../widgets/room_page/room_header_widget.dart';
import 'package:hoseomeet/features/home/data/models/room_post_detail.dart';

class RoomPage extends ConsumerStatefulWidget {
  final String postId;
  const RoomPage({Key? key, required this.postId}) : super(key: key);

  @override
  ConsumerState<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends ConsumerState<RoomPage> {
  @override
  Widget build(BuildContext context) {
    final roomNotifier = ref.read(roomPostProvider.notifier);

    return Scaffold(
      body: FutureBuilder<RoomDetail?>(
        future: roomNotifier.loadRoomDetail(int.parse(widget.postId)),
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
            // 버튼 클릭 시 동작
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
