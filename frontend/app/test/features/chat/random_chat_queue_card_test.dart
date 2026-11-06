import 'package:campusmeet/features/chat/data/models/random_chat_queue.dart';
import 'package:campusmeet/features/chat/presentation/widgets/random_chat_queue_card.dart';
import 'package:campusmeet/features/chat/providers/random_chat_queue_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget card(
  RandomChatQueueSnapshot queue, {
  VoidCallback? onLeave,
  VoidCallback? onOpen,
  VoidCallback? onJoin,
  VoidCallback? onRetry,
  bool uncertain = false,
  bool busy = false,
}) {
  return MaterialApp(
    home: Scaffold(
      body: RandomChatQueueCard(
        state: RandomChatQueueState(
          queue: queue,
          isBusy: busy,
          isStatusUncertain: uncertain,
        ),
        onJoin: onJoin ?? () {},
        onLeave: onLeave ?? () {},
        onOpenRoom: onOpen ?? () {},
        onRetry: onRetry ?? () {},
      ),
    ),
  );
}

void main() {
  testWidgets('waiting can be canceled, then matched room can be opened', (
    tester,
  ) async {
    var canceled = false;
    var opened = false;
    await tester.pumpWidget(
      card(
        const RandomChatQueueSnapshot(status: RandomChatQueueStatus.waiting),
        onLeave: () => canceled = true,
      ),
    );

    expect(find.text('상대를 찾고 있어요'), findsOneWidget);
    await tester.tap(find.text('대기 취소'));
    expect(canceled, isTrue);

    await tester.pumpWidget(
      card(
        const RandomChatQueueSnapshot(
          status: RandomChatQueueStatus.matched,
          streamId: 41,
        ),
        onOpen: () => opened = true,
      ),
    );
    expect(find.text('채팅 상대를 찾았어요'), findsOneWidget);
    await tester.tap(find.text('채팅방 열기'));
    expect(opened, isTrue);
  });

  testWidgets('busy operation disables duplicate taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      card(
        const RandomChatQueueSnapshot.idle(),
        busy: true,
        onJoin: () => taps++,
      ),
    );

    await tester.tap(find.byType(FilledButton));
    expect(taps, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('unconfirmed state replaces waiting with an explicit retry', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(card(
      const RandomChatQueueSnapshot(status: RandomChatQueueStatus.waiting),
      uncertain: true,
      onRetry: () => retries++,
    ));

    expect(find.text('상대를 찾고 있어요'), findsNothing);
    expect(find.text('매칭 상태를 확인하지 못했어요'), findsOneWidget);
    await tester.tap(find.text('다시 확인'));
    expect(retries, 1);

    // An expired server lease is shown as idle only after a successful read.
    await tester.pumpWidget(card(const RandomChatQueueSnapshot.idle()));
    expect(find.text('매칭 시작'), findsOneWidget);
    expect(find.text('매칭 상태를 확인하지 못했어요'), findsNothing);
  });
}
