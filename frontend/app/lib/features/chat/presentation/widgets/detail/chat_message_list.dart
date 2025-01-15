import 'package:flutter/cupertino.dart';
import 'package:hoseomeet/features/chat/data/models/chat_message.dart';

import '../../../../auth/data/models/user.dart';
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
      child: ListView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: messages.length,
        padding: const EdgeInsets.only(bottom: 10),
        itemBuilder: (context, index) {
          final msg = messages[index];
          // sender 찾기
          final sender = participants
              .where((u) => u.id == msg.senderId)
              .isNotEmpty
              ? participants.firstWhere((u) => u.id == msg.senderId)
              : null;

          return ChatMessageBubble(
            msg: msg,
            sender: sender,
          );
        },
      ),
    );
  }
}
