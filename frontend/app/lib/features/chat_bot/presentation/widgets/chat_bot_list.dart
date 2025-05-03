import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/chat_bot_message.dart';
import '../../providers/chat_bot_provicer.dart';

/// 채팅봇 메시지 리스트 + 자동 스크롤
class ChatBotMessageListView extends ConsumerWidget {
  final ScrollController scrollController;

  const ChatBotMessageListView({Key? key, required this.scrollController})
      : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(chatNotifierProvider);

    // 메시지 변화에 따라 자동 스크롤
    ref.listen<List<ChatBotChunk>>(chatNotifierProvider, (_, __) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    });

    return ListView.builder(
      controller: scrollController,
      itemCount: messages.length,
      itemBuilder: (_, i) {
        final m = messages[i];
        final isUser = m.role == 'user';
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            padding: const EdgeInsets.all(12),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7, // ✅ 최대 너비 제한
            ),
            decoration: BoxDecoration(
              color: isUser ? Colors.pink.shade100: Colors.grey[200],
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: isUser ? const Radius.circular(12) : const Radius.circular(0),
                bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(12),
              ),
            ),
            child: Text(
              m.content,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 15,
              ),
            ),
          ),
        );
      },
    );
  }
}
