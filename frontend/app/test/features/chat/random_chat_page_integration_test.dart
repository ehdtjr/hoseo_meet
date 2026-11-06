import 'dart:async';

import 'package:campusmeet/commons/network/auth_http_client.dart';
import 'package:campusmeet/features/auth/data/models/auth_state.dart';
import 'package:campusmeet/features/auth/data/services/auth_service.dart';
import 'package:campusmeet/features/auth/data/services/token_storage_service.dart';
import 'package:campusmeet/features/auth/providers/auth_notifier.dart';
import 'package:campusmeet/features/auth/providers/auth_notifier_provider.dart';
import 'package:campusmeet/features/chat/data/models/chat_room.dart';
import 'package:campusmeet/features/chat/data/models/random_chat_queue.dart';
import 'package:campusmeet/features/chat/data/services/chat_room_service.dart';
import 'package:campusmeet/features/chat/data/services/random_chat_service.dart';
import 'package:campusmeet/features/chat/presentation/pages/chat_page.dart';
import 'package:campusmeet/features/chat/providers/chat_room_provicer.dart';
import 'package:campusmeet/features/chat/providers/random_chat_queue_provider.dart';
import 'package:campusmeet/features/navigation/providers/bottom_nav_index_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryTokenStorage extends TokenStorageService {
  @override
  Future<String?> readRefreshToken() async => null;
}

class LoggedInAuthNotifier extends AuthNotifier {
  LoggedInAuthNotifier() : super(AuthService(), MemoryTokenStorage()) {
    state = AuthState(
      isLoading: false,
      isLoggedIn: true,
      accessToken: 'test-token',
    );
  }
}

class FakeRandomChatApi implements RandomChatQueueApi {
  RandomChatQueueSnapshot current = const RandomChatQueueSnapshot.idle();
  bool autoMatch = true;
  int statusCalls = 0;
  int joinCalls = 0;

  @override
  Future<RandomChatQueueSnapshot> getStatus() async {
    statusCalls++;
    if (autoMatch && current.status == RandomChatQueueStatus.waiting) {
      current = const RandomChatQueueSnapshot(
        status: RandomChatQueueStatus.matched,
        streamId: 41,
      );
    }
    return current;
  }

  @override
  Future<RandomChatQueueSnapshot> join() async {
    joinCalls++;
    current = const RandomChatQueueSnapshot(
      status: RandomChatQueueStatus.waiting,
    );
    return current;
  }

  @override
  Future<RandomChatQueueSnapshot> leave() async {
    current = const RandomChatQueueSnapshot.idle();
    return current;
  }
}

class FakeChatRoomService extends ChatRoomService {
  final FakeRandomChatApi randomChat;
  int loads = 0;
  Completer<void>? nextLoadGate;
  final List<ChatRoom> otherRooms = [];
  int? failUnsubscribeStream;
  bool loseRandomUnsubscribeResponse = false;

  FakeChatRoomService(Ref ref, this.randomChat) : super(AuthHttpClient(ref));

  @override
  Future<List<ChatRoom>> loadRoomList() async {
    loads++;
    final gate = nextLoadGate;
    nextLoadGate = null;
    if (gate != null) await gate.future;
    return [
      if (randomChat.current.status == RandomChatQueueStatus.matched)
        ChatRoom(
          streamId: randomChat.current.streamId!,
          creatorId: 1,
          type: 'random',
          name: '랜덤 채팅',
          isMuted: false,
          subscribers: [1, 2],
          unreadCount: 0,
          lastMessageContent: '',
          time: '',
        ),
      ...otherRooms,
    ];
  }

  @override
  Future<void> unsubscribeRoom(int streamId) async {
    if (streamId == failUnsubscribeStream) throw Exception('network');
    if (streamId == randomChat.current.streamId) {
      randomChat.current = const RandomChatQueueSnapshot.idle();
      if (loseRandomUnsubscribeResponse) throw Exception('response lost');
    }
    otherRooms.removeWhere((room) => room.streamId == streamId);
  }
}

class TestDetailPage extends ConsumerWidget {
  final ChatRoom room;

  const TestDetailPage({super.key, required this.room});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(
        children: [
          Text('matched-room-${room.streamId}'),
          TextButton(
            onPressed: () async {
              await ref
                  .read(chatRoomNotifierProvider.notifier)
                  .unsubscribe(room.streamId);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('테스트 채팅방 나가기'),
          ),
        ],
      ),
    );
  }
}

class PushObserver extends NavigatorObserver {
  int pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
    super.didPush(route, previousRoute);
  }
}

void main() {
  late FakeRandomChatApi randomApi;
  late FakeChatRoomService roomService;

  Future<void> pumpChatPage(
    WidgetTester tester, {
    NavigatorObserver? observer,
  }) async {
    randomApi = FakeRandomChatApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith((ref) => LoggedInAuthNotifier()),
          bottomNavIndexProvider.overrideWith((ref) => 2),
          randomChatQueueProvider.overrideWith((ref) {
            return RandomChatQueueController(
              randomApi,
              pollInterval: const Duration(milliseconds: 10),
              reconciliationDelay: Duration.zero,
            );
          }),
          chatRoomServiceProvider.overrideWith((ref) {
            roomService = FakeChatRoomService(ref, randomApi);
            return roomService;
          }),
        ],
        child: MaterialApp(
          navigatorObservers: observer == null ? const [] : [observer],
          home: ChatPage(
            chatDetailBuilder: (room) => TestDetailPage(room: room),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('chat tab joins, polls a match, and opens the created room',
      (tester) async {
    final observer = PushObserver();
    await pumpChatPage(tester, observer: observer);

    await tester.tap(find.text('매칭 시작'));
    await tester.pump();
    expect(find.text('상대를 찾고 있어요'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 15));
    await tester.pump();
    expect(find.text('채팅 상대를 찾았어요'), findsOneWidget);
    expect(roomService.loads, greaterThanOrEqualTo(2));

    final pushesBeforeOpen = observer.pushes;
    final openGate = Completer<void>();
    roomService.nextLoadGate = openGate;
    await tester.tap(find.text('채팅방 열기'));
    await tester.tap(find.text('채팅방 열기'));
    openGate.complete();
    await tester.pumpAndSettle();
    expect(observer.pushes, pushesBeforeOpen + 1);
    expect(find.text('matched-room-41'), findsOneWidget);
  });

  testWidgets(
      'leaving the chat tab stops polling and disposal keeps it stopped',
      (tester) async {
    await pumpChatPage(tester);
    randomApi.autoMatch = false;

    await tester.tap(find.text('매칭 시작'));
    await tester.pump(const Duration(milliseconds: 25));
    expect(randomApi.statusCalls, greaterThan(2));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChatPage)),
    );
    container.read(bottomNavIndexProvider.notifier).state = 0;
    await tester.pump();
    await tester.pump();
    final callsAfterLeaving = randomApi.statusCalls;
    await tester.pump(const Duration(milliseconds: 30));
    expect(randomApi.statusCalls, callsAfterLeaving);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 30));
    expect(randomApi.statusCalls, callsAfterLeaving);
  });

  testWidgets(
      'leaving a matched room from the normal list resets queue and allows rejoin',
      (tester) async {
    await pumpChatPage(tester);

    await tester.tap(find.text('매칭 시작'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 15));
    await tester.pump();
    expect(find.text('랜덤 채팅'), findsOneWidget);
    expect(randomApi.joinCalls, 1);

    await tester.tap(find.text('랜덤 채팅'));
    await tester.pumpAndSettle();
    expect(find.text('matched-room-41'), findsOneWidget);
    await tester.tap(find.text('테스트 채팅방 나가기'));
    await tester.pumpAndSettle();

    expect(find.text('매칭 시작'), findsOneWidget);
    expect(find.text('랜덤 채팅'), findsNothing);

    await tester.tap(find.text('매칭 시작'));
    await tester.pump();
    expect(randomApi.joinCalls, 2);
    expect(find.text('상대를 찾고 있어요'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 15));
    await tester.pump();
    expect(find.text('채팅 상대를 찾았어요'), findsOneWidget);
  });

  for (final loseResponse in [false, true]) {
    testWidgets(
        'bulk leave reconciles random room after ${loseResponse ? 'lost response' : 'partial failure'}',
        (tester) async {
      await pumpChatPage(tester);
      await tester.tap(find.text('매칭 시작'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 15));
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ChatPage)),
      );
      final rooms = container.read(chatRoomNotifierProvider.notifier);
      roomService.loseRandomUnsubscribeResponse = loseResponse;
      if (!loseResponse) {
        roomService.otherRooms.add(ChatRoom(
          streamId: 77,
          creatorId: 1,
          type: 'meet',
          name: '다른 채팅방',
          isMuted: false,
          subscribers: [1, 3],
          unreadCount: 0,
          lastMessageContent: '',
          time: '',
        ));
        roomService.failUnsubscribeStream = 77;
        await rooms.fetchRooms();
      }
      rooms.toggleExitMode();
      rooms.toggleRoomRemoval(41);
      if (!loseResponse) rooms.toggleRoomRemoval(77);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(RawMaterialButton));
      await tester.pumpAndSettle();

      expect(find.text('매칭 시작'), findsOneWidget);
      expect(find.text('랜덤 채팅'), findsNothing);
      expect(find.text('일부 채팅방에서 나가지 못했습니다. 다시 시도해주세요.'), findsOneWidget);
      if (!loseResponse) expect(find.text('다른 채팅방'), findsOneWidget);
    });
  }

  testWidgets('a changed matched stream refreshes the room list',
      (tester) async {
    await pumpChatPage(tester);
    await tester.tap(find.text('매칭 시작'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 15));
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChatPage)),
    );
    expect(container.read(chatRoomNotifierProvider).single.streamId, 41);
    randomApi.current = const RandomChatQueueSnapshot(
      status: RandomChatQueueStatus.matched,
      streamId: 42,
    );
    await container
        .read(randomChatQueueProvider.notifier)
        .refreshStatus(force: true);
    await tester.pumpAndSettle();
    expect(container.read(chatRoomNotifierProvider).single.streamId, 42);
  });
}
