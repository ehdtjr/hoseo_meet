import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/chat_room.dart';
import '../data/services/chat_room_service.dart';
import 'chat_room_notifier.dart';

import '../../../../commons/network/auth_http_client.dart';

/// authHttpClientProvider (예시)
final authHttpClientProvider = Provider<AuthHttpClient>((ref) {
  return AuthHttpClient(ref);
});

// ChatRoomService Provider
final chatRoomServiceProvider = Provider<ChatRoomService>((ref) {
  final client = ref.watch(authHttpClientProvider);
  return ChatRoomService(client);
});

// ChatRoomNotifier Provider
final chatRoomNotifierProvider =
StateNotifierProvider<ChatRoomNotifier, List<ChatRoom>>((ref) {
  final service = ref.watch(chatRoomServiceProvider);
  return ChatRoomNotifier(service);
});
