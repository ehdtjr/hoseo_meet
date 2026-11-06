import 'dart:async';
import 'dart:collection';

import 'package:campusmeet/features/chat/data/models/random_chat_queue.dart';
import 'package:campusmeet/features/chat/data/services/random_chat_service.dart';
import 'package:campusmeet/features/chat/providers/random_chat_queue_provider.dart';
import 'package:flutter_test/flutter_test.dart';

const idle = RandomChatQueueSnapshot.idle();
const waiting = RandomChatQueueSnapshot(status: RandomChatQueueStatus.waiting);
const matched = RandomChatQueueSnapshot(
  status: RandomChatQueueStatus.matched,
  streamId: 41,
);

class FakeRandomChatApi implements RandomChatQueueApi {
  final Queue<Future<RandomChatQueueSnapshot> Function()> statusResults =
      Queue();
  Future<RandomChatQueueSnapshot> Function()? joinResult;
  Future<RandomChatQueueSnapshot> Function()? leaveResult;
  int statusCalls = 0;

  @override
  Future<RandomChatQueueSnapshot> getStatus() {
    statusCalls++;
    return statusResults.removeFirst()();
  }

  @override
  Future<RandomChatQueueSnapshot> join() => joinResult!();

  @override
  Future<RandomChatQueueSnapshot> leave() => leaveResult!();
}

Future<RandomChatQueueSnapshot> value(RandomChatQueueSnapshot value) async =>
    value;
Future<RandomChatQueueSnapshot> failure() async => throw Exception('network');

void main() {
  late FakeRandomChatApi api;
  late RandomChatQueueController controller;

  setUp(() {
    api = FakeRandomChatApi();
    controller = RandomChatQueueController(
      api,
      pollInterval: const Duration(milliseconds: 10),
      reconciliationDelay: Duration.zero,
    );
  });

  tearDown(() => controller.dispose());

  test(
    'does not poll waiting state off-tab and detects a match after resume',
    () async {
      api.statusResults
        ..add(() => value(waiting))
        ..add(() => value(waiting))
        ..add(() => value(matched));

      await controller.initialize();
      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(api.statusCalls, 1);

      await controller.resume();
      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(controller.state.queue, same(matched));
      expect(controller.state.queue.streamId, 41);
    },
  );

  test('cancel can win while an older poll is still in flight', () async {
    final oldPoll = Completer<RandomChatQueueSnapshot>();
    api.statusResults
      ..add(() => value(waiting))
      ..add(() => oldPoll.future);
    api.leaveResult = () => value(idle);

    await controller.resume();
    await Future<void>.delayed(const Duration(milliseconds: 15));
    await controller.leave();
    expect(controller.state.queue.status, RandomChatQueueStatus.idle);

    oldPoll.complete(waiting);
    await Future<void>.delayed(Duration.zero);
    expect(
      controller.state.queue.status,
      RandomChatQueueStatus.idle,
      reason: 'the stale poll must not restore the canceled queue',
    );
  });

  test(
    'lost join response reconciles through idle to the matched room',
    () async {
      api.joinResult = failure;
      api.statusResults
        ..add(() => value(idle))
        ..add(() => value(idle))
        ..add(() => value(matched));

      await controller.join();

      expect(controller.state.queue.streamId, 41);
      expect(controller.state.errorMessage, isNull);
      expect(controller.state.isBusy, isFalse);
      expect(api.statusCalls, 3);
    },
  );

  test(
    'failed join remains idle and exposes an actionable retry message',
    () async {
      api.joinResult = failure;
      api.statusResults.addAll(
        List.generate(
          3,
          (_) => () => value(idle),
        ),
      );

      await controller.join();

      expect(controller.state.queue.status, RandomChatQueueStatus.idle);
      expect(
        controller.state.errorMessage,
        RandomChatQueueController.joinError,
      );
      expect(controller.state.isBusy, isFalse);
    },
  );

  test(
    'cancel failure keeps waiting and reports that cancellation failed',
    () async {
      api.leaveResult = failure;
      api.statusResults.addAll(
        List.generate(
          3,
          (_) => () => value(waiting),
        ),
      );

      await controller.leave();

      expect(controller.state.queue.status, RandomChatQueueStatus.waiting);
      expect(
        controller.state.errorMessage,
        RandomChatQueueController.leaveError,
      );
    },
  );

  test('cancel race surfaces the room when matching already won', () async {
    api.leaveResult = failure;
    api.statusResults.add(() => value(matched));

    await controller.leave();

    expect(controller.state.queue.streamId, 41);
    expect(controller.state.errorMessage, isNull);
  });

  testWidgets('polling failures stay uncertain beyond the server lease', (
    tester,
  ) async {
    controller.dispose();
    controller = RandomChatQueueController(
      api,
      pollInterval: const Duration(seconds: 5),
    );
    api.statusResults
      ..add(() => value(waiting))
      ..addAll(List.generate(20, (_) => failure));
    await controller.resume();
    expect(controller.state.isStatusUncertain, isFalse);

    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(seconds: 5));
      expect(controller.state.isStatusUncertain, isTrue);
    }
    // After 100 seconds without a successful heartbeat the server may have
    // expired this queue. Keep the last sample but do not claim it is current.
    expect(controller.state.queue.status, RandomChatQueueStatus.waiting);
    expect(controller.state.errorMessage, isNull);
    expect(api.statusCalls, 21);
    api.statusResults.add(() => value(idle));
    await controller.refreshStatus(force: true);
    expect(controller.state.isStatusUncertain, isFalse);
    expect(controller.state.queue.status, RandomChatQueueStatus.idle);
    final callsAfterRecovery = api.statusCalls;
    await tester.pump(const Duration(seconds: 10));
    expect(api.statusCalls, callsAfterRecovery);
    controller.pause();
  });

  test('room return forces a fresh read after an older in-flight status',
      () async {
    final oldStatus = Completer<RandomChatQueueSnapshot>();
    api.statusResults
      ..add(() => oldStatus.future)
      ..add(() => value(idle));
    final original = controller.refreshStatus();
    final afterLeave = controller.refreshStatus(force: true);
    expect(api.statusCalls, 1);
    oldStatus.complete(matched);
    await Future.wait([original, afterLeave]);
    expect(api.statusCalls, 2);
    expect(controller.state.queue.status, RandomChatQueueStatus.idle);
    expect(controller.state.isStatusUncertain, isFalse);
  });

  test('an obsolete failed poll cannot override successful cancellation',
      () async {
    final oldStatus = Completer<RandomChatQueueSnapshot>();
    api.statusResults.add(() => oldStatus.future);
    api.leaveResult = () => value(idle);
    final poll = controller.refreshStatus(showError: false);
    await controller.leave();
    oldStatus.completeError(Exception('network'));
    await poll;
    expect(controller.state.queue.status, RandomChatQueueStatus.idle);
    expect(controller.state.isStatusUncertain, isFalse);
    expect(controller.state.errorMessage, isNull);
  });
}
