import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:campusmeet/commons/network/auth_http_client_provider.dart';
import 'package:campusmeet/features/auth/providers/auth_notifier_provider.dart';
import 'package:campusmeet/features/chat/data/models/chat_message.dart';
import 'package:campusmeet/features/chat/data/models/chat_room.dart';
import 'package:campusmeet/features/chat/data/services/socket_message_service.dart';
import 'package:campusmeet/features/chat/providers/chat_detail_notifier.dart';
import 'package:campusmeet/features/chat/providers/chat_detail_provider.dart';
import 'package:campusmeet/features/chat/providers/socket_message_service_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chat_detail_recovery_test.dart'
    show HistoryClient, TestAuthService, message;
import 'socket_message_service_test.dart' show waitFor;

class _Harness {
  late HttpServer server;
  final sockets = <WebSocket>[];
  late ProviderContainer container;
  late HistoryClient client;
  late SocketMessageService socket;
  late ChatDetailNotifier notifier;
  late ProviderSubscription<ChatDetailState> listener;
  late AutoDisposeStateNotifierProvider<ChatDetailNotifier, ChatDetailState>
      provider;
  int _eventId = 0;

  static Future<_Harness> open(
      {int newest = 1,
      Map<int, int> counts = const {},
      void Function(HistoryClient)? configure}) async {
    final harness = _Harness();
    FlutterSecureStorage.setMockInitialValues({});
    harness.server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    harness.server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      socket.listen((_) {}, onError: (Object _) {});
      harness.sockets.add(socket);
    });
    harness.container = ProviderContainer(overrides: [
      authServiceProvider.overrideWithValue(TestAuthService()),
      authHttpClientProvider
          .overrideWith((ref) => harness.client = HistoryClient(ref)),
      socketMessageServiceFactoryProvider.overrideWithValue(({
        required tokenProvider,
        required onConnected,
      }) =>
          harness.socket = SocketMessageService(
              tokenProvider: tokenProvider,
              onConnected: onConnected,
              socketUrl: 'ws://127.0.0.1:${harness.server.port}',
              initialRetryDelay: const Duration(milliseconds: 10))),
    ]);
    addTearDown(harness.close);
    final auth = harness.container.read(authNotifierProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await auth.loginUser('token', 'password');
    harness.container.read(authHttpClientProvider);
    harness.client.newest = newest;
    harness.client.unreadCounts.addAll(counts);
    configure?.call(harness.client);
    final room = ChatRoom(
        streamId: 7,
        creatorId: 1,
        type: 'meet',
        name: 'test',
        isMuted: false,
        subscribers: [],
        unreadCount: 0,
        lastMessageContent: '',
        time: '');
    harness.provider = chatDetailNotifierProvider(room);
    harness.listener = harness.container.listen(harness.provider, (_, __) {});
    harness.notifier = harness.container.read(harness.provider.notifier);
    await harness.notifier.init();
    await waitFor(() =>
        harness.socket.connectionState == SocketConnectionState.connected);
    return harness;
  }

  List<ChatMessage> get messages => container.read(provider).messages;

  void readEvent(List<int> ids) => sockets.last.add(jsonEncode({
        'type': 'read',
        'data': {'read_message': ids},
        'last_event_id': 'receipt-${++_eventId}',
      }));

  Future<void> close() async {
    await notifier.disposeNotifier();
    listener.close();
    container.dispose();
    for (final socket in sockets) {
      await socket.close();
    }
    await server.close(force: true);
  }
}

void main() {
  test(
      'pause clears server presence before a rapid resume reactivates the room',
      () async {
    final h = await _Harness.open();
    expect(h.client.activeStream, 7);
    final gate = Completer<void>();
    final deactivationStarted = Completer<void>();
    h.client.beforePost = (path, body) async {
      if (path.endsWith('/deactive')) {
        if (!deactivationStarted.isCompleted) deactivationStarted.complete();
        await gate.future;
      }
    };
    final pausing = h.notifier.pauseConnection();
    await deactivationStarted.future;
    final activations =
        h.client.posts.where((post) => post.path.endsWith('/active')).length;
    final resuming = h.notifier.resumeConnection();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(h.client.posts.where((post) => post.path.endsWith('/active')).length,
        activations);
    gate.complete();
    await Future.wait([pausing, resuming]);
    expect(h.client.activeStream, 7);
    await h.notifier.pauseConnection();
    expect(h.client.activeStream, isNull,
        reason:
            'The backend FCM strategy requires no active stream while the socket is paused');
  });

  test('resume refreshes receipts on all cached messages without new messages',
      () async {
    final h = await _Harness.open(newest: 3, counts: {1: 2, 2: 1, 3: 1});
    expect(h.messages.map((m) => m.unreadCount), [2, 1, 1]);
    await h.notifier.pauseConnection();
    h.client.unreadCounts.addAll({1: 0, 2: 0, 3: 0});
    await h.notifier.resumeConnection();
    expect(h.messages.map((m) => m.id), [1, 2, 3]);
    expect(h.messages.map((m) => m.unreadCount), [0, 0, 0]);
  });

  test(
      'a delayed read event already in the HTTP snapshot cannot decrement twice',
      () async {
    final h = await _Harness.open(newest: 3, counts: {1: 2});
    await h.notifier.pauseConnection();
    h.client.unreadCounts[1] = 1;
    await h.notifier.resumeConnection();
    expect(h.messages.first.unreadCount, 1);
    final requests = h.client.anchors.length;
    h.readEvent([1]);
    await waitFor(() => h.client.anchors.length > requests);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(h.messages.first.unreadCount, 1);
  });

  test(
      'read changes during an in-flight receipt snapshot trigger a fresh snapshot',
      () async {
    final h = await _Harness.open(newest: 3, counts: {1: 2});
    final captured = Completer<void>();
    final gate = Completer<void>();
    var blockOnce = true;
    h.client.afterLoad = (anchor) async {
      if (anchor == '3' && blockOnce) {
        blockOnce = false;
        captured.complete();
        await gate.future;
      }
    };
    h.client.unreadCounts[1] = 1;
    h.readEvent([1]);
    await captured.future;
    h.client.unreadCounts[1] = 0;
    h.readEvent([1]);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    gate.complete();
    await waitFor(() => h.messages.first.unreadCount == 0);
  });

  test(
      'recovery and live reads never mark messages newer than the displayed ID',
      () async {
    final h = await _Harness.open(
        newest: 100,
        configure: (client) {
          client.beforePost = (path, body) async {
            if (path.endsWith('/flags/stream')) client.newest++;
          };
        });
    expect(h.client.newest, 101);
    expect(h.messages.last.id, 100);
    expect(h.client.markedIds, isNot(contains(101)));
    final recoveryRead = h.client.posts
        .lastWhere((post) => post.path.endsWith('/flags/stream'))
        .body;
    expect(recoveryRead, containsPair('anchor', '100'));
    expect(recoveryRead, containsPair('num_before', 99));
    expect(recoveryRead, containsPair('num_after', 0));
    h.sockets.last.add(jsonEncode(
        {'type': 'stream', 'data': message(101), 'last_event_id': '101-0'}));
    await waitFor(() => h.client.markedIds.contains(101));
    expect(h.client.newest, 102);
    expect(h.client.markedIds, isNot(contains(102)));
  });

  test(
      'dispose ignores an in-flight receipt response and schedules no further reads',
      () async {
    final h = await _Harness.open(newest: 3, counts: {1: 2});
    final captured = Completer<void>();
    final gate = Completer<void>();
    h.client.afterLoad = (anchor) async {
      if (anchor == '3') {
        captured.complete();
        await gate.future;
      }
    };
    h.client.unreadCounts[1] = 0;
    h.readEvent([1]);
    await captured.future;
    await h.notifier.disposeNotifier();
    final requests = h.client.anchors.length;
    gate.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(h.messages.first.unreadCount, 2);
    expect(h.client.anchors, hasLength(requests));
    expect(h.socket.connectionState, SocketConnectionState.disposed);
  });

  test('automatic reconnect restores presence lost during a server restart',
      () async {
    final h = await _Harness.open();
    h.client.activeStream = null;
    final connections = h.sockets.length;
    await h.sockets.last.close();
    await waitFor(() =>
        h.sockets.length > connections &&
        h.socket.connectionState == SocketConnectionState.connected);
    expect(h.client.activeStream, 7);
  });
}
