import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoseomeet/features/chat/data/models/chat_message.dart';
import 'package:intl/intl.dart';

import '../../../../auth/data/models/user.dart';
import '../../../../auth/providers/user_profile_provider.dart';

class ChatMessageBubble extends ConsumerWidget {
  final ChatMessage msg;
  final User? sender;

  const ChatMessageBubble({
    super.key,
    required this.msg,
    required this.sender,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileState = ref.watch(userProfileNotifierProvider);
    final isMe = (msg.senderId == userProfileState.userProfile?.id);
    final sendTime = _formatTime(msg.dateSent);

    if (isMe) {
      // 내가 보낸 메시지
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
                if (msg.unreadCount > 0)
                  Text(
                    '${msg.unreadCount}',
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                  ),
                Text(
                  sendTime,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(width: 6),
            // 말풍선
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.pink.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    msg.content,
                    style: const TextStyle(color: Colors.black),
                    softWrap: true,
                    overflow: TextOverflow.clip,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 상대방 메시지
    final profileUrl = sender?.profile?.trim();
    final hasValidProfile = isValidProfileUrl(profileUrl);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 프로필 이미지 또는 아이콘
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.grey.shade300,
            backgroundImage: hasValidProfile ? NetworkImage(profileUrl!) : null,
            child: hasValidProfile ? null : const Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 8),

          // 닉네임 + 말풍선
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sender?.name ?? "알 수 없는 사용자",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
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
                            msg.content,
                            style: const TextStyle(color: Colors.black),
                            softWrap: true,
                            overflow: TextOverflow.clip,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // 읽지 않은 개수 + 시간
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (msg.unreadCount > 0)
                          Text(
                            '${msg.unreadCount}',
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

String _formatTime(DateTime dateTime) {
  try {
    final localTime = dateTime.toLocal();
    return DateFormat('a h:mm', 'ko_KR').format(localTime);
  } catch (e, stack) {
    debugPrint('[ChatDetailPage] 타임스탬프 변환 오류: $e\n$stack');
    return 'Unknown';
  }
}

bool isValidProfileUrl(String? url) {
  if (url == null || url.trim().isEmpty || url == 'default_profile') return false;
  final uri = Uri.tryParse(url.trim());
  return uri != null && uri.hasAbsolutePath && uri.hasScheme;
}
