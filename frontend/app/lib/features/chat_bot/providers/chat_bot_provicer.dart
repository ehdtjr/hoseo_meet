import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../commons/network/auth_http_client_provider.dart';
import '../data/models/chat_bot_message.dart';
import '../data/services/chat_bot_service.dart';
import 'chat_bot_notifier.dart';

final chatStreamServiceProvider = Provider<ChatStreamService>((ref) {
  final client = ref.watch(authHttpClientProvider);
  return ChatStreamService(client);
});

final chatNotifierProvider =
StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final service = ref.watch(chatStreamServiceProvider);
  return ChatNotifier(service);
});
