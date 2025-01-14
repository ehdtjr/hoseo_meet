import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../commons/network/auth_http_client_provider.dart';
import '../data/models/meet_post.dart';
import '../data/services/meet_poset_service.dart';
import 'meet_post_notifier.dart';

/// MeePostService Provider
final meePostServiceProvider = Provider<MeePostService>((ref) {
  final client = ref.watch(authHttpClientProvider);
  return MeePostService(client);
});

/// MeetPostNotifier Provider
final meetPostProvider =
StateNotifierProvider<MeetPostNotifier, List<MeetPost>>((ref) {
  final service = ref.watch(meePostServiceProvider);
  return MeetPostNotifier(service, ref);
});
