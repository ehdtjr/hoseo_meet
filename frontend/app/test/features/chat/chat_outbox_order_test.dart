import 'package:campusmeet/features/auth/providers/auth_notifier_provider.dart';
import 'package:campusmeet/features/chat/data/models/chat_message.dart';
import 'package:campusmeet/features/chat/providers/chat_detail_notifier.dart';
import 'package:campusmeet/features/chat/providers/chat_room_provicer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chat_detail_send_test.dart' show SeededRoomsNotifier, room;
import 'chat_socket_logging_test.dart' show LoggedInAuth, SocketRepository;

class OutboxRepository extends SocketRepository {
  final readAnchors = <int>[];

  @override
  Future<void> markLoadedMessagesAsRead({
    required int streamId,
    required int anchorId,
    required int numBefore,
  }) async {
    readAnchors.add(anchorId);
  }
}

void main() {
  test('late outbox retries preserve the latest room preview and read each ID',
      () async {
    final repository = OutboxRepository()..historySnapshot = [];
    final rooms = SeededRoomsNotifier();
    final provider = StateNotifierProvider<ChatDetailNotifier, ChatDetailState>(
        (ref) => ChatDetailNotifier(ref, room, repository: repository));
    final container = ProviderContainer(overrides: [
      authNotifierProvider.overrideWith((ref) => LoggedInAuth()),
      chatRoomNotifierProvider.overrideWith((ref) => rooms),
    ]);
    final notifier = container.read(provider.notifier);
    final newestTime = DateTime.utc(2026, 11, 6, 12, 2);
    try {
      await notifier.init();
      for (final id in [102, 101, 102]) {
        repository.events.add({
          'type': 'stream',
          'data': {
            'id': id,
            'sender_id': 1,
            'recipient_id': 7,
            'stream_id': 7,
            'content': 'message $id',
            'date_sent': id == 102
                ? newestTime.toIso8601String()
                : newestTime
                    .subtract(const Duration(minutes: 1))
                    .toIso8601String(),
            'unread_count': 2,
            'type': 1,
          },
        });
        await Future<void>.delayed(Duration.zero);
        expect(rooms.state.single.lastMessageContent, 'message 102');
        expect(DateTime.parse(rooms.state.single.time).toUtc(), newestTime);
      }
      expect(container.read(provider).messages.map((m) => m.id), [101, 102]);
      expect(repository.readAnchors, [102, 101]);
      expect(rooms.state.single.unreadCount, 0);
    } finally {
      await notifier.disposeNotifier();
      await repository.events.close();
      container.dispose();
    }
  });
}
