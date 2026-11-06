import 'package:flutter/material.dart';

import '../../data/models/random_chat_queue.dart';
import '../../providers/random_chat_queue_provider.dart';

class RandomChatQueueCard extends StatelessWidget {
  final RandomChatQueueState state;
  final VoidCallback onJoin;
  final VoidCallback onLeave;
  final VoidCallback onOpenRoom;
  final VoidCallback onRetry;

  const RandomChatQueueCard({
    super.key,
    required this.state,
    required this.onJoin,
    required this.onLeave,
    required this.onOpenRoom,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final status = state.queue.status;
    final (label, buttonLabel, callback) = state.isStatusUncertain
        ? ('매칭 상태를 확인하지 못했어요', '다시 확인', onRetry)
        : switch (status) {
            RandomChatQueueStatus.idle => (
                '새로운 상대와 채팅방을 연결해요',
                '매칭 시작',
                onJoin
              ),
            RandomChatQueueStatus.waiting => ('상대를 찾고 있어요', '대기 취소', onLeave),
            RandomChatQueueStatus.matched => (
                '채팅 상대를 찾았어요',
                '채팅방 열기',
                onOpenRoom
              ),
          };

    return Container(
      key: const Key('random-chat-card'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0B3AD), width: 0.75),
      ),
      child: Row(
        children: [
          Icon(
            state.isStatusUncertain
                ? Icons.sync_problem_outlined
                : status == RandomChatQueueStatus.waiting
                    ? Icons.hourglass_top_rounded
                    : Icons.forum_outlined,
            color: const Color(0xFFE72410),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '랜덤채팅',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF707070),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 34,
            child: FilledButton(
              key: Key(state.isStatusUncertain
                  ? 'random-chat-retry-button'
                  : 'random-chat-${status.name}-button'),
              onPressed: state.isBusy ? null : callback,
              style: FilledButton.styleFrom(
                backgroundColor: status == RandomChatQueueStatus.waiting
                    ? const Color(0xFF707070)
                    : const Color(0xFFE72410),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: state.isBusy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}
