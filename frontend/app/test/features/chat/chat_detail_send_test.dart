import 'dart:async';
import 'package:campusmeet/features/chat/data/models/chat_message.dart';
import 'package:campusmeet/features/chat/data/models/chat_room.dart';
import 'package:campusmeet/features/chat/data/models/outgoing_message.dart';
import 'package:campusmeet/features/chat/data/repositories/chat_repository.dart';
import 'package:campusmeet/features/chat/data/services/send_message_service.dart';
import 'package:campusmeet/features/chat/data/services/chat_room_service.dart';
import 'package:campusmeet/features/chat/providers/chat_room_notifier.dart';
import 'package:campusmeet/features/chat/providers/chat_room_provicer.dart';
import 'package:campusmeet/features/chat/presentation/pages/chat_detail_page.dart';
import 'package:campusmeet/features/chat/providers/chat_detail_notifier.dart';
import 'package:campusmeet/features/chat/providers/chat_detail_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';

final room = ChatRoom(
    streamId: 7,
    creatorId: 1,
    type: 'meet',
    name: '테스트',
    isMuted: false,
    subscribers: [],
    unreadCount: 0,
    lastMessageContent: '',
    time: '');

class SendAttempt {
  final String content;
  final String id;
  final Completer<void> completion = Completer<void>();
  SendAttempt(this.content, this.id);
}

class StubRoomService implements ChatRoomService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SeededRoomsNotifier extends ChatRoomNotifier {
  SeededRoomsNotifier() : super(StubRoomService()) {
    state = [room.copyWith(lastMessageContent: '이전 메시지', unreadCount: 3)];
  }
}

class ControlledRepository implements ChatRepository {
  final List<SendAttempt> attempts = [];
  List<ChatMessage> serverMessages = [];
  bool readFails = false;
  bool markReadFails = false;
  int? readAnchor;
  int? readNumBefore;
  int loadCalls = 0;
  final Set<int> readIds = {};
  VoidCallback? onMarkRead;
  @override
  Future<void> markLoadedMessagesAsRead(
      {required int streamId,
      required int anchorId,
      required int numBefore}) async {
    readAnchor = anchorId;
    readNumBefore = numBefore;
    if (markReadFails) {
      throw http.ClientException('read acknowledgement failed');
    }
    final loaded = serverMessages.where((m) => m.id <= anchorId).toList()
      ..sort((a, b) => b.id.compareTo(a.id));
    final newlyRead = loaded
        .take(numBefore + 1)
        .where((m) => !readIds.contains(m.id))
        .map((m) => m.id)
        .toSet();
    readIds.addAll(newlyRead);
    serverMessages = [
      for (final message in serverMessages)
        newlyRead.contains(message.id) && message.unreadCount > 0
            ? message.copyWith(unreadCount: message.unreadCount - 1)
            : message
    ];
    onMarkRead?.call();
  }

  Completer<List<ChatMessage>>? pendingRead;
  @override
  Future<void> sendMessage(
      {required int streamId,
      required String content,
      required String clientMessageId}) {
    final attempt = SendAttempt(content, clientMessageId);
    attempts.add(attempt);
    return attempt.completion.future;
  }

  @override
  Future<List<ChatMessage>> loadMessages(
      {required int streamId,
      String anchor = 'first_unread',
      int numBefore = 10,
      int numAfter = 30}) async {
    loadCalls++;
    if (readFails) throw http.ClientException('read unavailable');
    if (pendingRead != null) return pendingRead!.future;
    final anchorId = int.tryParse(anchor);
    if (anchorId == null) return serverMessages;
    return serverMessages.where((m) => m.id <= anchorId).toList();
  }

  @override
  Future<void> deactivateRoom() async {}
  @override
  Future<void> closeWebSocket() async {}
  @override
  Future<void> disposeSocketService() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Exercise the real send state machine without opening a socket or GPS timer.
class TestDetailNotifier extends ChatDetailNotifier {
  TestDetailNotifier(super.ref, super.chatRoom, {required super.repository});
  @override
  Future<void> init() async {}
  @override
  Future<void> startLocationTracking() async {}
}

void main() {
  late ControlledRepository repository;
  late ChatDetailNotifier notifier;
  late SeededRoomsNotifier roomsNotifier;
  setUpAll(() => initializeDateFormatting('ko_KR'));
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    repository = ControlledRepository();
    roomsNotifier = SeededRoomsNotifier();
  });

  Future<void> pumpChat(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      chatRoomNotifierProvider.overrideWith((ref) => roomsNotifier),
      chatDetailNotifierProvider(room).overrideWith((ref) {
        notifier = TestDetailNotifier(ref, room, repository: repository);
        return notifier;
      }),
    ], child: MaterialApp(home: ChatDetailPage(chatRoom: room))));
    await tester.pumpAndSettle();
  }

  String draft(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;
  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.tap(find.byKey(const ValueKey('chat-send-button')));
    await tester.pump();
  }

  for (final failure in [
    const MessageSendException(403),
    const MessageSendException(500),
    http.ClientException('offline')
  ]) {
    testWidgets(
        'failure $failure retains editor, status and original retry body',
        (tester) async {
      await pumpChat(tester);
      await send(tester, '  원문 & +  ');
      repository.attempts.first.completion.completeError(failure);
      await tester.pumpAndSettle();
      expect(draft(tester), '  원문 & +  ');
      expect(find.text('전송 실패 · 내용을 보관했습니다'), findsOneWidget);
      expect(notifier.state.outgoingMessages.single.status,
          MessageSendStatus.failed);
      await tester.enterText(find.byType(TextField), '다음 초안');
      await tester.tap(find.text('재전송'));
      await tester.pump();
      expect(repository.attempts, hasLength(2));
      expect(repository.attempts.last.content, '원문 & +');
      expect(repository.attempts.last.id, repository.attempts.first.id);
      repository.attempts.last.completion.complete();
      await tester.pumpAndSettle();
      expect(draft(tester), '다음 초안');
      expect(find.text('재전송'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'slow success clears only its unchanged draft and displays server message',
      (tester) async {
    await pumpChat(tester);
    await send(tester, '보낸 문장');
    expect(draft(tester), '보낸 문장');
    expect(find.text('전송 중…'), findsOneWidget);
    repository.serverMessages = [
      ChatMessage(
          id: 42,
          senderId: 1,
          recipientId: 7,
          content: '보낸 문장',
          renderedContent: null,
          dateSent: DateTime.now(),
          unreadCount: 0,
          type: 1,
          streamId: 7)
    ];
    repository.attempts.first.completion.complete();
    await tester.pumpAndSettle();
    expect(draft(tester), isEmpty);
    expect(find.text('보낸 문장'), findsOneWidget);
    expect(notifier.state.messages.single.id, 42);
    expect(notifier.state.outgoingMessages, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'duplicate presses make one request while new typing survives success',
      (tester) async {
    await pumpChat(tester);
    await send(tester, '첫 문장');
    await tester.tap(find.byKey(const ValueKey('chat-send-button')));
    expect(await notifier.sendMessage('중복 호출'), isFalse);
    await tester.enterText(find.byType(TextField), '새 문장');
    expect(repository.attempts, hasLength(1));
    repository.attempts.first.completion.complete();
    await tester.pumpAndSettle();
    expect(draft(tester), '새 문장');
    expect(repository.attempts.single.content, '첫 문장');
  });

  testWidgets('editing away and back to identical text preserves the new draft',
      (tester) async {
    await pumpChat(tester);
    await send(tester, '같은 문장');
    await tester.enterText(find.byType(TextField), '다른 문장');
    await tester.enterText(find.byType(TextField), '같은 문장');
    repository.attempts.first.completion.complete();
    await tester.pumpAndSettle();
    expect(draft(tester), '같은 문장');
  });

  testWidgets('send button retries unchanged failed draft with same ID',
      (tester) async {
    await pumpChat(tester);
    await send(tester, '실패 원문');
    repository.attempts.first.completion
        .completeError(const MessageSendException(500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat-send-button')));
    await tester.pump();
    expect(repository.attempts.last.id, repository.attempts.first.id);
    repository.attempts.last.completion.complete();
    await tester.pumpAndSettle();
    expect(draft(tester), isEmpty);
  });

  testWidgets(
      'a failed history read never changes acknowledged send to failure',
      (tester) async {
    await pumpChat(tester);
    repository.readFails = true;
    await send(tester, '성공한 문장');
    repository.attempts.first.completion.complete();
    await tester.pumpAndSettle();
    expect(draft(tester), isEmpty);
    expect(notifier.state.outgoingMessages, isEmpty);
    expect(find.text('재전송'), findsNothing);
  });

  testWidgets(
      'failed original remains retryable when editor changed during request',
      (tester) async {
    await pumpChat(tester);
    await send(tester, '원문');
    await tester.enterText(find.byType(TextField), '새 초안');
    repository.attempts.first.completion
        .completeError(http.ClientException('offline'));
    await tester.pumpAndSettle();
    expect(draft(tester), '새 초안');
    expect(notifier.state.outgoingMessages.single.draft, '원문');
    expect(find.text('원문'), findsOneWidget);
  });

  testWidgets('acknowledged send clears its draft while history is pending',
      (tester) async {
    await pumpChat(tester);
    repository.pendingRead = Completer<List<ChatMessage>>();
    await send(tester, '성공한 문장');
    repository.attempts.first.completion.complete();
    await tester.pumpAndSettle();
    expect(draft(tester), isEmpty);
    expect(notifier.state.isSending, isFalse);
    repository.pendingRead!.complete([]);
    await tester.pumpAndSettle();
  });

  ChatMessage serverMessage(int id, {int unreadCount = 2}) => ChatMessage(
        id: id,
        senderId: 1,
        recipientId: 7,
        content: '메시지 $id',
        renderedContent: null,
        dateSent: DateTime(2026, 11, 6, 7, id),
        unreadCount: unreadCount,
        type: 1,
        streamId: 7,
      );

  testWidgets(
      'HTTP recovery marks its fetched range read and refreshes counts and room preview without a socket',
      (tester) async {
    await pumpChat(tester);
    repository.serverMessages = [serverMessage(41), serverMessage(42)];
    await send(tester, '메시지 42');
    repository.attempts.first.completion.complete();
    await tester.pumpAndSettle();
    expect(repository.readAnchor, 42);
    expect(repository.readNumBefore, 1);
    expect(repository.readIds, {41, 42});
    expect(notifier.state.messages.map((m) => m.unreadCount), [1, 1],
        reason: 'Other participants must remain unread');
    expect(roomsNotifier.state.single.lastMessageContent, '메시지 42');
    expect(roomsNotifier.state.single.time,
        repository.serverMessages.last.dateSent.toString());
    expect(roomsNotifier.state.single.unreadCount, 0);
    expect(repository.loadCalls, 2);
    expect(draft(tester), isEmpty);
  });

  testWidgets(
      'recovery uses a fixed anchor and never marks a later arrival read',
      (tester) async {
    await pumpChat(tester);
    repository.serverMessages = [serverMessage(42)];
    repository.onMarkRead =
        () => repository.serverMessages.add(serverMessage(43));
    await send(tester, '메시지 42');
    repository.attempts.first.completion.complete();
    await tester.pumpAndSettle();
    expect(repository.readIds, {42});
    expect(repository.serverMessages.last.unreadCount, 2);
    expect(notifier.state.messages.map((m) => m.id), [42]);
    expect(roomsNotifier.state.single.lastMessageContent, '메시지 42');
  });

  testWidgets(
      'read acknowledgement failure keeps the successful message and room preview',
      (tester) async {
    await pumpChat(tester);
    repository.serverMessages = [serverMessage(42)];
    repository.markReadFails = true;
    await send(tester, '메시지 42');
    repository.attempts.first.completion.complete();
    await tester.pumpAndSettle();
    expect(draft(tester), isEmpty);
    expect(notifier.state.outgoingMessages, isEmpty);
    expect(notifier.state.messages.single.id, 42);
    expect(notifier.state.messages.single.unreadCount, 2);
    expect(roomsNotifier.state.single.lastMessageContent, '메시지 42');
    expect(find.text('재전송'), findsNothing);
    expect(repository.loadCalls, 1);
  });

  testWidgets(
      'a late history response never marks messages read after closing the room',
      (tester) async {
    await pumpChat(tester);
    repository.pendingRead = Completer<List<ChatMessage>>();
    await send(tester, '메시지 42');
    repository.attempts.first.completion.complete();
    await tester.pumpAndSettle();
    await notifier.disposeNotifier();
    repository.pendingRead!.complete([serverMessage(42)]);
    await tester.pumpAndSettle();
    expect(repository.readAnchor, isNull);
    expect(notifier.state.messages, isEmpty);
    expect(roomsNotifier.state.single.lastMessageContent, '이전 메시지');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'pending completion after leaving page does not touch disposed editor',
      (tester) async {
    await pumpChat(tester);
    await send(tester, '원문');
    await tester.pumpWidget(const SizedBox());
    repository.attempts.first.completion.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
