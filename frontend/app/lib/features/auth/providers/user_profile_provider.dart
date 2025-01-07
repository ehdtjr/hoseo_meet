import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoseomeet/features/auth/data/services/user_service.dart';
import 'package:hoseomeet/features/auth/providers/user_profile_notifier.dart';

import '../../../commons/network/auth_http_client_provider.dart';
import '../data/models/user.dart';

final userServiceProvider = Provider<UserService>((ref) {
  final client = ref.watch(authHttpClientProvider);
  return UserService(client);
});

final userProfileNotifierProvider =
StateNotifierProvider<UserProfileNotifier, UserProfileState>((ref) {
  final service = ref.watch(userServiceProvider);
  return UserProfileNotifier(userService: service);
});
