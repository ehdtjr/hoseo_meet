import 'package:campusmeet/features/chat/data/models/chat_message.dart';
import 'package:campusmeet/features/chat/data/services/message_recovery_service.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage message(int id) => ChatMessage.fromJson({
      'id': id,
      'stream_id': 7,
      'date_sent': '2026-11-06T00:00:00Z',
      'content': '$id',
    });

void main() {
  test(
    'fills a multi-page gap with inclusive anchors and a fixed watermark',
    () async {
      final history = List.generate(351, (i) => message(i + 1));
      final anchors = <String>[];
      final service = MessageRecoveryService(({
        required streamId,
        String anchor = 'first_unread',
        int numBefore = 10,
        int numAfter = 30,
      }) async {
        anchors.add(anchor);
        if (anchor == 'newest') return [history.last];
        final id = int.parse(anchor);
        // More traffic arrives after the server watermark was taken.
        history.add(message(history.last.id + 1));
        return history.where((m) => m.id >= id).take(numAfter + 1).toList();
      });
      final recovered = await service.recover(
        streamId: 7,
        afterId: 1,
        isActive: () => true,
      );
      expect(recovered.map((m) => m.id), List.generate(351, (i) => i + 1));
      expect(anchors, ['newest', '1', '101', '201', '301']);
    },
  );

  test(
    'bootstraps an empty local room from oldest, including messages not queued in Redis',
    () async {
      final service = MessageRecoveryService(({
        required streamId,
        String anchor = 'first_unread',
        int numBefore = 10,
        int numAfter = 30,
      }) async {
        if (anchor == 'newest') return [message(9)];
        expect(anchor, 'oldest');
        return [message(4), message(6), message(9)];
      });
      final recovered = await service.recover(
        streamId: 7,
        isActive: () => true,
      );
      expect(recovered.map((m) => m.id), [4, 6, 9]);
    },
  );

  test('empty server room returns no messages', () async {
    final service = MessageRecoveryService(
      ({
        required streamId,
        String anchor = 'first_unread',
        int numBefore = 10,
        int numAfter = 30,
      }) async =>
          [],
    );
    expect(await service.recover(streamId: 7, isActive: () => true), isEmpty);
  });

  test(
    'stalled or failed pages fail recovery instead of silently advancing',
    () async {
      var failPage = true;
      final service = MessageRecoveryService(({
        required streamId,
        String anchor = 'first_unread',
        int numBefore = 10,
        int numAfter = 30,
      }) async {
        if (anchor == 'newest') return [message(9)];
        if (failPage) throw StateError('offline');
        return [message(1)];
      });
      await expectLater(
        service.recover(streamId: 7, afterId: 1, isActive: () => true),
        throwsStateError,
      );
      failPage = false;
      await expectLater(
        service.recover(streamId: 7, afterId: 1, isActive: () => true),
        throwsStateError,
      );
    },
  );

  test(
    'disposal during a page prevents subsequent requests and partial results',
    () async {
      var active = true;
      var requests = 0;
      final service = MessageRecoveryService(({
        required streamId,
        String anchor = 'first_unread',
        int numBefore = 10,
        int numAfter = 30,
      }) async {
        requests++;
        if (anchor == 'newest') return [message(351)];
        active = false;
        return [message(1), message(2)];
      });
      expect(
        await service.recover(streamId: 7, afterId: 1, isActive: () => active),
        isEmpty,
      );
      expect(requests, 2);
    },
  );

  test('receipt refresh batches cached pages and returns authoritative counts',
      () async {
    final cached =
        List.generate(351, (i) => message(i + 1).copyWith(unreadCount: 2));
    var requests = 0;
    final service = MessageRecoveryService((
        {required streamId,
        String anchor = 'first_unread',
        int numBefore = 10,
        int numAfter = 30}) async {
      requests++;
      final last = int.parse(anchor);
      expect(numAfter, 0);
      expect(numBefore, lessThan(100));
      return [for (var id = last - numBefore; id <= last; id++) message(id)];
    });
    final refreshed = await service.refreshReadStates(
        streamId: 7,
        cachedMessages: cached,
        messageIds: {1, 99, 100, 101, 351},
        isActive: () => true);
    final byId = {for (final m in refreshed) m.id: m};
    expect([1, 99, 100, 101, 351].map((id) => byId[id]!.unreadCount),
        everyElement(0));
    expect(requests, 3);
  });

  test('receipt refresh handles cache holes without inserting unknown messages',
      () async {
    final requests = <String>[];
    final service = MessageRecoveryService((
        {required streamId,
        String anchor = 'first_unread',
        int numBefore = 10,
        int numAfter = 30}) async {
      requests.add(anchor);
      final last = int.parse(anchor);
      return [for (var id = last - numBefore; id <= last; id++) message(id)];
    });
    final refreshed = await service.refreshReadStates(
        streamId: 7,
        cachedMessages: [message(1), message(400)],
        messageIds: {1, 400},
        isActive: () => true);
    expect(refreshed.map((m) => m.id).toSet(), {1, 400});
    expect(requests, ['400', '1']);
  });
}
