import 'package:flutter/material.dart';
import 'package:hoseomeet/features/chat/presentation/widgets/chat_toggle_button.dart';
import '../../data/models/chat_room.dart';
import 'chat_room_item.dart';

class ChatRoomList extends StatelessWidget {
  final List<ChatRoom> rooms;
  final bool isExitMode;
  final Set<int> selectedRoomIds; // 선택된 Room ID 목록
  final Function(int roomId) onRoomToggle; // 선택 상태 변경 콜백

  const ChatRoomList({
    super.key,
    required this.rooms,
    required this.isExitMode,
    required this.selectedRoomIds,
    required this.onRoomToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        final isSelected = selectedRoomIds.contains(room.streamId);

        return Padding(
          padding: const EdgeInsets.only(left: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              if (isExitMode) ...[
                ToggleCircleButton(
                  isSelected: isSelected,
                  onTap: () => onRoomToggle(room.streamId),
                ),
                const SizedBox(width: 20),
              ],
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
