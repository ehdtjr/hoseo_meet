import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoseomeet/features/home/presentation/widgets/room_page/room_custom_scroll_view.dart';
import '../../providers/room/room_post_provider.dart';
import '../widgets/room_page/room_header_widget.dart';
import 'package:hoseomeet/features/home/data/models/room_post_detail.dart';

class RoomPage extends ConsumerStatefulWidget {
  final String postId;
  const RoomPage({super.key, required this.postId});

  @override
  _RoomPageState createState() => _RoomPageState();
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
                RoomHeaderWidget(
                  expandedHeight: 300,
                  imageUrls: roomDetail.images,
                ),
                Expanded(
                  child: RoomCustomScrollView(roomDetail: roomDetail),
                ),
              ],
            );
          }
        },
      ),
    );
  }
}
