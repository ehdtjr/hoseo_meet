import 'package:flutter/material.dart';
import 'package:hoseomeet/features/chat/presentation/widgets/chat_toggle_button.dart';
import '../../data/models/chat_room.dart';
import 'chat_room_item.dart';

class ChatRoomList extends StatelessWidget {
  final List<ChatRoom> rooms;

  const ChatRoomList({super.key, required this.rooms});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        return Padding(
          padding: const EdgeInsets.only(left: 5), // 왼쪽 패딩 3px
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start, // 왼쪽 정렬 설정
            children: [
              const ToggleCircleButton(), // 토글 버튼 추가
              const SizedBox(width: 20), // 토글 버튼과 항목 사이 간격
              Expanded(
                child: ChatRoomItem(room: room),
              ),
            ],
          ),
        );
      },
    );
  }
}
