import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_notifier_provider.dart';
import '../data/models/chat_message.dart';
import '../data/models/chat_room.dart';
import 'chat_detail_notifier.dart';

final chatDetailNotifierProvider = StateNotifierProvider.autoDispose
    .family<ChatDetailNotifier, ChatDetailState, ChatRoom>((ref, chatRoom) {
  final notifier = ChatDetailNotifier(ref, chatRoom);
  ref.listen(authNotifierProvider, (previous, next) {
    if (previous?.accessToken != next.accessToken ||
        previous?.isLoggedIn != next.isLoggedIn) {
      notifier.authenticationChanged();
    }
  });
  return notifier;
});
