import 'package:campusmeet/features/home/presentation/widgets/bottom_sheet/bottom_category_list/room/room_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../providers/room/room_post_provider.dart';

class RoomContainerWidget extends ConsumerStatefulWidget {
  const RoomContainerWidget({super.key});

  @override
  _RoomContainerWidgetState createState() => _RoomContainerWidgetState();
}

class _RoomContainerWidgetState extends ConsumerState<RoomContainerWidget> {
  bool isLoading = false;
  bool hasMore = true;
  bool _isDisposed = false;

  late final notifier = ref.read(roomPostProvider.notifier);

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
    notifier.resetAndLoad();

    if (_isDisposed) return; // dispose 상태에서 setState 방지

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadInitialData,
      child: const RoomPostList(),
    );
  }
}
