import 'package:flutter/material.dart';
import '../../data/models/chat_room.dart';

class ChatRoomItem extends StatelessWidget {
  final ChatRoom room;

  const ChatRoomItem({
    Key? key,
    required this.room,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // (A) 안 읽은 메시지 수
    final int unreadCount = room.unreadCount;
    // (B) 채팅방 타입
    final String typeDisplay = room.typeKr;
    // (C) 제목
    final String title = room.name.isEmpty ? '(제목 없음)' : room.name;
    // (D) 메시지
    final String message = room.lastMessageContent.isEmpty
        ? '(메시지 없음)'
        : room.lastMessageContent;
    // (E) 시간
    final String timeDisplay = room.time;

    return Container(
      // 상단 여백 20
      margin: const EdgeInsets.only(top: 20),
      // Column으로 전체 구성
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // (1) Divider를 제외한 나머지를 묶어, 좌우 10pt 패딩 적용
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1) 첫 줄: 타입 태그
                Container(
                  width: 40,
                  height: 20,
                  decoration: BoxDecoration(
                    border: Border.all(width: 1, color: const Color(0xFFE72410)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      typeDisplay,
                      style: const TextStyle(
                        color: Color(0xFFE72410),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                // 2) 두 번째 줄: 제목(왼쪽), 안 읽은 수(오른쪽)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (unreadCount > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE72410),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 4),

                // 3) 세 번째 줄: 메시지(왼쪽), 시간(오른쪽)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(
                          color: Color(0xFF707070),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      timeDisplay,
                      style: const TextStyle(
                        color: Color(0xFF707070),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),

          // (2) 구분선(Divider)은 패딩 바깥, 전체 폭 사용
          const Divider(
            color: Color(0xFFF0B3AD),
            thickness: 0.75,
          ),
        ],
      ),
    );
  }
}
