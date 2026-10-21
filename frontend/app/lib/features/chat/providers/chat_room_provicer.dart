import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../commons/network/auth_http_client_provider.dart';
import '../data/models/chat_room.dart';
import '../data/services/chat_room_service.dart';
import 'chat_room_notifier.dart';


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
