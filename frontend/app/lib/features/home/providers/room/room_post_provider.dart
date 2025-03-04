import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoseomeet/features/home/providers/room/room_post_notifier.dart';
import '../../../../commons/network/auth_http_client_provider.dart';
import '../../data/models/room_post.dart';
import '../../data/services/room_post_service.dart';

final roomServiceProvider = Provider<RoomService>((ref) {
  final client = ref.watch(authHttpClientProvider);
  return RoomService(client);
});

final roomPostProvider = StateNotifierProvider<RoomPostNotifier, List<RoomPost>>((ref) {
  final service = ref.watch(roomServiceProvider);
  return RoomPostNotifier(service, ref);
});
