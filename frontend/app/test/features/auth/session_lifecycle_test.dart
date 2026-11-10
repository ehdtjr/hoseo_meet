import 'dart:async';

import 'package:campusmeet/commons/services/session_lifecycle.dart';
import 'package:campusmeet/features/auth/providers/auth_notifier_provider.dart';
import 'package:campusmeet/features/chat/presentation/pages/chat_page.dart';
import 'package:campusmeet/features/chat/data/models/random_chat_queue.dart';
import 'package:campusmeet/features/chat/providers/chat_room_provicer.dart';
import 'package:campusmeet/features/chat/providers/random_chat_queue_provider.dart';
import 'package:campusmeet/features/navigation/providers/bottom_nav_index_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../chat/random_chat_page_integration_test.dart' as fixtures;

class GatedAuth extends fixtures.LoggedInAuthNotifier {
  GatedAuth() {
    state = state.copyWith(refreshToken: 'saved-refresh');
  }
  Completer<bool>? gate;
  int checks = 0;
  @override
  Future<bool> ensureValidSession() async {
    checks++;
    return gate == null ? true : await gate!.future;
  }
}

void main() {
  for (final outcome in [
    'success',
    'failure',
    'background-again',
    'disposed'
  ]) {
    testWidgets('foreground chat waits for authentication: $outcome',
        (tester) async {
      final auth = GatedAuth();
      final api = fixtures.FakeRandomChatApi();
      late fixtures.FakeChatRoomService rooms;
      final container = ProviderContainer(overrides: [
        authNotifierProvider.overrideWith((ref) => auth),
        randomChatQueueApiProvider.overrideWithValue(api),
        chatRoomServiceProvider.overrideWith(
            (ref) => rooms = fixtures.FakeChatRoomService(ref, api)),
      ]);
      addTearDown(container.dispose);
      container.read(bottomNavIndexProvider.notifier).state = 2;
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const SessionLifecycle(child: MaterialApp(home: ChatPage())),
      ));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      final loads = rooms.loads;
      final statuses = api.statusCalls;
      auth.gate = Completer<bool>();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(auth.checks,
          greaterThanOrEqualTo(2)); // global + page share auth gate
      expect(rooms.loads, loads);
      expect(api.statusCalls, statuses);
      if (outcome == 'background-again') {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      } else if (outcome == 'disposed') {
        await tester.pumpWidget(const SizedBox());
      }
      auth.gate!.complete(outcome != 'failure');
      await tester.pumpAndSettle();
      expect(rooms.loads, outcome == 'success' ? loads + 1 : loads);
      expect(api.statusCalls, outcome == 'success' ? statuses + 1 : statuses);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  for (final outcome in ['recover', 'pause', 'dispose', 'leave-tab']) {
    testWidgets('failed resume keeps recovery intent until $outcome',
        (tester) async {
      final auth = GatedAuth();
      final api = fixtures.FakeRandomChatApi()
        ..autoMatch = false
        ..current = const RandomChatQueueSnapshot(
            status: RandomChatQueueStatus.waiting);
      late fixtures.FakeChatRoomService rooms;
      final container = ProviderContainer(overrides: [
        authNotifierProvider.overrideWith((ref) => auth),
        randomChatQueueApiProvider.overrideWithValue(api),
        chatRoomServiceProvider.overrideWith(
            (ref) => rooms = fixtures.FakeChatRoomService(ref, api)),
      ]);
      addTearDown(container.dispose);
      container.read(bottomNavIndexProvider.notifier).state = 2;
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const SessionLifecycle(child: MaterialApp(home: ChatPage())),
      ));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      auth.gate = Completer<bool>()..complete(false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(container.read(randomChatQueueProvider).isStatusUncertain, isTrue);
      expect(find.text('매칭 상태를 확인하지 못했어요'), findsOneWidget);
      final loads = rooms.loads;
      final statuses = api.statusCalls;
      final checks = auth.checks;
      auth.gate = null; // Network restored without another lifecycle event.
      if (outcome == 'pause') {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      } else if (outcome == 'dispose') {
        await tester.pumpWidget(const SizedBox());
      } else if (outcome == 'leave-tab') {
        container.read(bottomNavIndexProvider.notifier).state = 0;
        await tester.pumpAndSettle();
      }
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      if (outcome == 'recover') {
        expect(rooms.loads, greaterThan(loads));
        expect(api.statusCalls, greaterThan(statuses));
        expect(
            container.read(randomChatQueueProvider).isStatusUncertain, isFalse);
        final afterResume = api.statusCalls;
        api.current = const RandomChatQueueSnapshot(
            status: RandomChatQueueStatus.matched, streamId: 41);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(api.statusCalls, greaterThan(afterResume));
        expect(container.read(randomChatQueueProvider).queue.streamId, 41);
      } else {
        expect(rooms.loads, loads);
        expect(api.statusCalls, statuses);
        expect(auth.checks, checks);
      }
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
