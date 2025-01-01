// features/chat/providers/chat_detail_provider.dart

import 'package:riverpod/riverpod.dart';
import 'chat_detail_notifier.dart';

final chatDetailNotifierProvider = StateNotifierProvider.family<
    ChatDetailNotifier,
    ChatDetailState,
    Map<String, dynamic>>(
      (ref, chatRoom) {
    // ChatDetailNotifier의 생성자: (this.ref, this.chatRoom)
    return ChatDetailNotifier(ref, chatRoom);
  },
);
