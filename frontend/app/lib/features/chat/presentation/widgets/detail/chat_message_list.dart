import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../../commons/services/block_manager.dart';
import '../../../../auth/data/models/user.dart';
import '../../../data/models/chat_message.dart';
import 'chat_message_bubble.dart';

class ChatMessageListView extends StatelessWidget {
  final ScrollController scrollController;
  final List<ChatMessage> messages;
  final List<User> participants;

  const ChatMessageListView({
    super.key,
    required this.scrollController,
    required this.messages,
    required this.participants,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: FutureBuilder<List<int>>(
        future: BlockedUsers.getBlockedUserIds(),
        builder: (context, snapshot) {
          final blockedIds = snapshot.data ?? [];

          return ListView.builder(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: messages.length,
            padding: const EdgeInsets.only(bottom: 10),
            itemBuilder: (context, index) {
              final msg = messages[index];
              final sender = participants
                  .where((u) => u.id == msg.senderId)
                  .isNotEmpty
                  ? participants.firstWhere((u) => u.id == msg.senderId)
                  : null;

              final isBlocked = blockedIds.contains(msg.senderId);
              final modifiedMsg = isBlocked
                  ? msg.copyWith(content: '차단된 사용자의 메시지입니다')
                  : msg;

              return ChatMessageBubble(
                msg: modifiedMsg,
                sender: sender,
              );
            },
          );
        },
      ),
    );
  }
}
