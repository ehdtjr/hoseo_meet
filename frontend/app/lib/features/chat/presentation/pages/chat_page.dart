// file: lib/features/chat/presentation/pages/chat_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 전역 Provider (chatRoomNotifier) + chatCategoryProvider
import 'package:hoseomeet/features/chat/providers/chat_room_provicer.dart';
import 'package:hoseomeet/features/chat/providers/chat_category_provider.dart';

// UI 위젯
import '../../data/models/chat_room.dart';
import '../widgets/chat_header.dart';
import '../widgets/chat_category_bar.dart';
import '../widgets/chat_room_list.dart';


class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({Key? key}) : super(key: key);

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  bool _isInitialLoading = true; // 첫 로딩 시 표시용

  @override
  void initState() {
    super.initState();

    // 페이지 진입 시 한 번 fetchRooms()
    Future.microtask(() async {
      await ref.read(chatRoomNotifierProvider.notifier).fetchRooms();
      setState(() {
        _isInitialLoading = false;
      });
    });
  }

  /// Pull-to-Refresh
  Future<void> _onRefresh() async {
    await ref.read(chatRoomNotifierProvider.notifier).fetchRooms();
  }

  @override
  Widget build(BuildContext context) {
    // 1) 전체 채팅방 목록
    final chatRooms = ref.watch(chatRoomNotifierProvider);

    // 2) 현재 선택된 카테고리(enum)
    final selectedCategory = ref.watch(chatCategoryProvider);

    // 3) 필터
    final filteredRooms = _filterRoomsByCategory(chatRooms, selectedCategory);

    // 로딩 표시
    if (_isInitialLoading && chatRooms.isEmpty) {
      return const Scaffold(
        body: SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // 정상 화면
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ChatHeader(),
              const SizedBox(height: 25),
              // 카테고리 바
              const ChatCategoryBar(),
              const SizedBox(height: 10),

              // Pull-to-Refresh
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: ChatRoomList(rooms: filteredRooms),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// rooms 목록을 카테고리에 따라 필터링
  List<ChatRoom> _filterRoomsByCategory(
      List<ChatRoom> rooms,
      ChatCategory cat,
      ) {
    switch (cat) {
      case ChatCategory.all:
        return rooms;
      case ChatCategory.meet:
        return rooms.where((r) => r.type == 'meet').toList();
      case ChatCategory.delivery:
        return rooms.where((r) => r.type == 'delivery').toList();
      case ChatCategory.taxi:
      // 서버에서 "taxiCarpool" 혹은 "taxi_carpool" 로 저장 가능. 확인 후 수정
        return rooms.where((r) => r.type == 'taxiCarpool').toList();
    }
  }
}
