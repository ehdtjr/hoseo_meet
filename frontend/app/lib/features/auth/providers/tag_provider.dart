import 'package:campusmeet/features/auth/providers/tag_notifier.dart';
import 'package:campusmeet/features/auth/providers/user_profile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/tag.dart';

final tagNotifierProvider = StateNotifierProvider<TagNotifier, TagState>(
      (ref) {
    final userService = ref.read(userServiceProvider);
    return TagNotifier(userService: userService);
  },
);
