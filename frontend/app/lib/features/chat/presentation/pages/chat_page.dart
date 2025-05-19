import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../navigation/providers/bottom_nav_index_provider.dart';
import '../../data/models/chat_room.dart';
import '../../providers/chat_category_provider.dart';
import '../../providers/chat_room_provicer.dart';
import '../widgets/chat_header.dart';
import '../widgets/chat_category_bar.dart';
import '../widgets/chat_room_list.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  bool _isInitialLoading = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      await ref.read(chatRoomNotifierProvider.notifier).fetchRooms();
      setState(() {
        _isInitialLoading = false;
      });
    });
  }

  Future<void> _onRefresh() async {
    await ref.read(chatRoomNotifierProvider.notifier).fetchRooms();
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(bottomNavIndexProvider);

    if (currentIndex == 2 && !_isInitialized) {
      _isInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(chatRoomNotifierProvider.notifier).fetchRooms();
      });
    }

    if (currentIndex != 2) {
      _isInitialized = false;
    }

    final chatRooms = ref.watch(chatRoomNotifierProvider);
    final selectedCategory = ref.watch(chatCategoryProvider);
    final isExitMode = ref.watch(chatRoomNotifierProvider.notifier).isExitMode;
    final filteredRooms = _filterRoomsByCategory(chatRooms, selectedCategory);

    if (_isInitialLoading && chatRooms.isEmpty) {
      return const Scaffold(
        body: SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ChatHeader(
                isExitMode: isExitMode,
                onToggleExitMode: () =>
                    ref.read(chatRoomNotifierProvider.notifier).toggleExitMode(),
              ),
              const SizedBox(height: 25),
              const ChatCategoryBar(),
              const SizedBox(height: 10),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: filteredRooms.isEmpty
                      ? _buildEmptyState()
                      : ChatRoomList(
                    rooms: filteredRooms,
                    isExitMode: isExitMode,
                    selectedRoomIds: ref
                        .watch(chatRoomNotifierProvider.notifier)
                        .roomsToRemove
                        .map((room) => room.streamId)
                        .toSet(),
                    onRoomToggle: (roomId) {
                      ref
                          .read(chatRoomNotifierProvider.notifier)
                          .toggleRoomRemoval(roomId);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: isExitMode
          ? RawMaterialButton(
        onPressed: () async {
          final notifier =
          ref.read(chatRoomNotifierProvider.notifier);

          if (notifier.roomsToRemove.isNotEmpty) {
            try {
              await notifier.removeSelectedRooms();
              notifier.toggleExitMode();
            } catch (e) {
              print('Error while removing selected rooms: $e');
            }
          } else {
            print('No rooms selected for removal.');
          }
        },
        shape: const CircleBorder(),
        child: SvgPicture.asset(
          'assets/icons/chat-remove-button.svg',
          width: 43,
          height: 43,
        ),
      )
          : null,
    );
  }

  List<ChatRoom> _filterRoomsByCategory(List<ChatRoom> rooms, ChatCategory cat) {
    switch (cat) {
      case ChatCategory.all:
        return rooms;
      case ChatCategory.meet:
        return rooms.where((r) => r.type == 'meet').toList();
      case ChatCategory.delivery:
        return rooms.where((r) => r.type == 'delivery').toList();
      case ChatCategory.taxi:
        return rooms.where((r) => r.type == 'taxi').toList();
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/icons/empty_chat.svg',
            width: 100,
            height: 100,
            color: const Color(0xFFE72410), // 포인트 컬러
            placeholderBuilder: (context) => const Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: Color(0xFFE72410),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '채팅방이 비어 있어요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Meet 게시판 통해\n새로운 대화를 시작해보세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey,
              fontWeight: FontWeight.w400,
              height: 1.4,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }


}
