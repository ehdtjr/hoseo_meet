// lib/features/chat/data/providers/chat_providers.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat_bot_message.dart';
import '../data/services/chat_bot_service.dart';

class ChatNotifier extends StateNotifier<List<ChatBotChunk>> {
  final ChatStreamService _service;
  StreamSubscription<ChatBotChunk>? _sub;
  bool _isStreaming = false;

  ChatNotifier(this._service) : super([]);

  bool get isStreaming => _isStreaming;

  /// prompt를 보내고, user/assistant 청크를 받아 state에 반영
  void sendMessage(String prompt) {
    if (_isStreaming) return;

    _sub?.cancel();
    _isStreaming = true;

    _sub = _service.streamMessages(prompt: prompt).listen(
          (chunk) {
        if (chunk.role == 'user') {
          state = [...state, chunk];
        } else {
          if (state.isNotEmpty && state.last.role == 'assistant') {
            final updated = ChatBotChunk(
              userId: chunk.userId,
              role: chunk.role,
              content: chunk.content, // ✅ 덮어쓰기
            );
            state = [...state.sublist(0, state.length - 1), updated];
          } else {
            state = [...state, chunk];
          }
        }
      },
      onDone: () => _isStreaming = false,
      onError: (_) => _isStreaming = false,
    );
  }


  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
