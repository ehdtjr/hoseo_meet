import 'package:campusmeet/features/auth/providers/user_profile_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../commons/network/auth_http_client_provider.dart';
import '../data/models/user.dart';
import '../data/services/user_service.dart';

final userServiceProvider = Provider<UserService>((ref) {
  final client = ref.watch(authHttpClientProvider);
  return UserService(client);
});

final userProfileNotifierProvider =
StateNotifierProvider<UserProfileNotifier, UserProfileState>((ref) {
  final service = ref.watch(userServiceProvider);
  return UserProfileNotifier(userService: service);
});
