import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/chat_bot_message.dart';
import '../data/services/chat_bot_service.dart';

class ChatNotifier extends StateNotifier<ChatState> {
  final ChatStreamService _service;
  StreamSubscription<ChatBotChunk>? _sub;

  ChatNotifier(this._service)
      : super(const ChatState(messages: [], isStreaming: false));

  void sendMessage(String prompt, {bool showInUI = true}) {
    if (state.isStreaming || state.isFinished) return;

    _sub?.cancel();
    state = state.copyWith(isStreaming: true);

    _sub = _service.streamMessages(prompt: prompt).listen(
          (chunk) {
        final current = [...state.messages];

        final isEndMessage = chunk.content.contains('이제 대화는 여기까지야! 고마워 :)');
        if (chunk.role == 'user') {
          if (showInUI) current.add(chunk);
        } else {
          if (current.isNotEmpty && current.last.role == 'assistant') {
            current[current.length - 1] = chunk;
          } else {
            current.add(chunk);
          }
        }

        state = state.copyWith(
          messages: current,
          isFinished: isEndMessage ? true : state.isFinished,
        );

        if (isEndMessage) {
          _sub?.cancel();
        }
      },
      onDone: () => state = state.copyWith(isStreaming: false),
      onError: (_) => state = state.copyWith(isStreaming: false),
    );
  }


  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
