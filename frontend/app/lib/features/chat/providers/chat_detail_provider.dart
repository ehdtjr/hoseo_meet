// features/chat/providers/chat_detail_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/chat_message.dart';
import '../data/models/chat_room.dart';
import 'chat_detail_notifier.dart';

/// (1) StateNotifierProvider.family의 세 번째 타입을 `ChatRoom`으로 변경
final chatDetailNotifierProvider = StateNotifierProvider.family<
    ChatDetailNotifier,
    ChatDetailState,
    ChatRoom>(
      (ref, chatRoom) {
    // (2) ChatDetailNotifier의 생성자에 ChatRoom을 직접 넘김
    return ChatDetailNotifier(ref, chatRoom);
  },
);
