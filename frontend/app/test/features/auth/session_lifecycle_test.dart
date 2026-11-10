import 'dart:async';

import 'package:campusmeet/commons/services/session_lifecycle.dart';
import 'package:campusmeet/features/auth/providers/auth_notifier_provider.dart';
import 'package:campusmeet/features/chat/presentation/pages/chat_page.dart';
import 'package:campusmeet/features/chat/providers/chat_room_provicer.dart';
import 'package:campusmeet/features/chat/providers/random_chat_queue_provider.dart';
import 'package:campusmeet/features/navigation/providers/bottom_nav_index_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../chat/random_chat_page_integration_test.dart' as fixtures;

class GatedAuth extends fixtures.LoggedInAuthNotifier {
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
      await tester.pumpWidget(const SizedBox());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(tester.takeException(), isNull);
    });
  }
}
