import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/chat_room.dart';

// ChatDetailPage 경로에 맞춰 import
import '../../presentation/pages/chat_detail_page.dart';

class ChatRoomItem extends StatelessWidget {
  final ChatRoom room;

  const ChatRoomItem({
    super.key,
    required this.room,
  });

  @override
  Widget build(BuildContext context) {
    // 안 읽은 메시지 수
    final int unreadCount = room.unreadCount;
    final String typeDisplay = room.typeKr;
    final String title = room.name.isEmpty ? '(제목 없음)' : room.name;
    final String message = room.lastMessageContent.isEmpty
        ? '(메시지 없음)'
        : room.lastMessageContent;
    final String timeDisplay = formatTimeString(room.time);

    // (A) unreadCount > 0 → 빨간 테두리/글자 (기존 스타일)
    //    unreadCount == 0 → 회색 배경 + 흰 글자
    late BoxDecoration tagDecoration;
    late TextStyle tagTextStyle;

    if (unreadCount > 0) {
      // 기존 스타일 (빨간 테두리, 빨간 글자)
      tagDecoration = BoxDecoration(
        border: Border.all(width: 1, color: const Color(0xFFE72410)),
        borderRadius: BorderRadius.circular(10),
      );
      tagTextStyle = const TextStyle(
        color: Color(0xFFE72410),
        fontSize: 12,
        fontWeight: FontWeight.w500,
      );
    } else {
      // 새로운 스타일 (회색 배경, 흰 글자)
      tagDecoration = BoxDecoration(
        color: const Color(0xFF707070),
        borderRadius: BorderRadius.circular(10),
      );
      tagTextStyle = const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      );
    }

    return GestureDetector(
      // 탭 시 ChatDetailPage 이동
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatDetailPage(chatRoom: room),
          ),
        );
      },

      child: Container(
        margin: const EdgeInsets.only(top: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // (1) Divider 제외 부분: 좌우 10px 패딩
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // (1) 타입 태그
                  Container(
                    width: 40,
                    height: 20,
                    decoration: tagDecoration,
                    child: Center(
                      child: Text(
                        typeDisplay,
                        style: tagTextStyle,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // (2) 제목(왼쪽), 안 읽은 수(오른쪽)
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
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE72410), // 배지 빨간
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

                  // (3) 메시지(왼쪽), 시간(오른쪽)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          message.length > 20 ? '${message.substring(0, 20)}...' : message,
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
            // (4) 구분선 (전체 폭)
            const Divider(
              color: Color(0xFFF0B3AD),
              thickness: 0.75,
            ),
          ],
        ),
      ),
    );
  }
}

/// 오늘이면 "오전 10:53", 아니면 "8월 1일" (월/일)
String formatTimeString(String isoString) {
  if (isoString.isEmpty) return '';

  try {
    final dt = DateTime.parse(isoString).toLocal();
    final now = DateTime.now();
    final isSameDay =
    (dt.year == now.year && dt.month == now.month && dt.day == now.day);

    if (isSameDay) {
      return DateFormat('a h:mm', 'ko_KR').format(dt); // 예: "오전 10:53"
    } else {
      return DateFormat('M월 d일', 'ko_KR').format(dt); // 예: "8월 1일"
    }
  } catch (e) {
    return isoString; // 파싱 실패 시 원본 반환
  }
}
