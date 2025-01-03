// file: chat_room_list.dart
import 'package:flutter/material.dart';
import '../../data/models/chat_room.dart';
import 'chat_room_item.dart';

class ChatRoomList extends StatelessWidget {
  final List<ChatRoom> rooms;

  const ChatRoomList({Key? key, required this.rooms}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        // ChatRoomItem 역시 ChatRoom 객체를 받아 표시하도록 수정
        return ChatRoomItem(room: room);
      },
    );
  }
}
