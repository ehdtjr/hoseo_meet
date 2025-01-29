import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoseomeet/commons/network/auth_http_client_provider.dart';
import 'package:hoseomeet/features/story/providers/story_post_notifier.dart';

import '../data/models/story_post.dart';
import '../data/services/story_post_service.dart';

final storyPostServiceProvider = Provider<StoryPostService>((ref) {
  final client = ref.watch(authHttpClientProvider);
  return StoryPostService(client);
});

final storyPostProvider =
StateNotifierProvider<StoryPostNotifier, List<StoryPost>>((ref) {
  final service = ref.watch(storyPostServiceProvider);
  return StoryPostNotifier(service);
});