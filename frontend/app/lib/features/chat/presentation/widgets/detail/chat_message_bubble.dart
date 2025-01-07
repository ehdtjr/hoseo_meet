import 'package:flutter/material.dart';

class ChatMessageBubble extends StatelessWidget {
  final bool isMe;
  final String? content;
  final int unreadCount;
  final String sendTime;
  final String? senderProfileUrl;
  final String? senderName;

  const ChatMessageBubble({
    super.key,
    required this.isMe,
    required this.content,
    required this.unreadCount,
    required this.sendTime,
    this.senderProfileUrl,
    this.senderName,
  });

  @override
  Widget build(BuildContext context) {
    // (1) 내 메시지
    if (isMe) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 읽지 않은 개수, 시간
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (unreadCount > 0)
                  Text(
                    '$unreadCount',
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                  ),
                Text(
                  sendTime,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(width: 6),
            // 말풍선: Flexible로 감싸서 화면 폭이 부족할 때 자동 줄바꿈
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  // 화면 폭의 70%까지 차지할 수 있도록 제한
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.pink.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    content ?? '',
                    style: const TextStyle(color: Colors.black),
                    softWrap: true,         // 줄바꿈 허용
                    overflow: TextOverflow.clip, // 넘치면 잘라내기 (또는 ellipsis)
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // (2) 상대 메시지
    else {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 프로필
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: (senderProfileUrl != null)
                  ? NetworkImage(senderProfileUrl!)
                  : null,
            ),
            const SizedBox(width: 8),

            // 닉네임 + 말풍선 + 안읽은수
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (senderName != null)
                    Text(
                      senderName!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  const SizedBox(height: 4),

                  // 말풍선 + 시간(안읽은수)를 가로로 배치
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // 말풍선
                      Flexible(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.7,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              content ?? '',
                              style: const TextStyle(color: Colors.black),
                              softWrap: true,
                              overflow: TextOverflow.clip,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // 안 읽은 개수 + 시간
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (unreadCount > 0)
                            Text(
                              '$unreadCount',
                              style: const TextStyle(color: Colors.red, fontSize: 14),
                            ),
                          Text(
                            sendTime,
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }
}
