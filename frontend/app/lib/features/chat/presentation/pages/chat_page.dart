import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/chat_category_provider.dart';
import '../../providers/chat_room_provicer.dart';
import '../widgets/chat_header.dart';
import '../widgets/chat_category_bar.dart';
import '../widgets/chat_room_list.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({Key? key}) : super(key: key);

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  bool _isLoading = true; // 간단한 로딩 상태 플래그

  @override
  void initState() {
    super.initState();

    // (A) 페이지 초기화 시, 채팅방 목록 불러오기
    //     fetchRooms() 완료 후 _isLoading를 false로 전환
    Future.microtask(() async {
      await ref.read(chatRoomNotifierProvider.notifier).fetchRooms();
      setState(() {
        _isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // (1) 채팅방 목록 (List<ChatRoom>)
    final chatRooms = ref.watch(chatRoomNotifierProvider);

    // (2) 현재 카테고리
    final selectedCategory = ref.watch(chatCategoryProvider);

    // (3) 필터 로직
    final filteredRooms = chatRooms.where((room) {
      if (selectedCategory == '전체') return true;
      return room.type == selectedCategory;
    }).toList();

    // (B) 만약 아직 로딩 중이면 프로그래스 표시
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // (C) 로딩 완료된 경우
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단 헤더
              const ChatHeader(),

              const SizedBox(height: 25),

              // 카테고리 바
              const ChatCategoryBar(),

              Expanded(
                child: ChatRoomList(rooms: filteredRooms),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
